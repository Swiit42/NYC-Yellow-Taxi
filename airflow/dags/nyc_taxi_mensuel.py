"""Pipeline mensuel des trajets TLC : chargement RAW, puis staging, intermediate et marts.

Chargement : fichier du mois -> stage Snowflake -> RAW.YELLOW_TRIPDATA.
Transformations : fichiers SQL fournis (include/sql/), une tâche par fichier, regroupées
par couche. Des contrôles (SQLCheckOperator) arrêtent la chaîne si les données sont mauvaises.

Un run par mois (janvier à mars 2025, rejoués par catchup). Le fichier est déduit de la
date logique du run, jamais de la date du jour : relancer le run de janvier en octobre
recharge toujours janvier. Ne pas utiliser le bouton Trigger (run daté d'aujourd'hui,
dont le fichier n'existe pas).

Rejouable : PUT sans OVERWRITE et COPY INTO sans FORCE ne rechargent pas un fichier
déjà chargé (statut LOAD_SKIPPED), donc relancer un run n'ajoute aucune ligne.
"""
from pathlib import Path

import pendulum
import requests
from airflow.providers.common.sql.operators.sql import SQLCheckOperator, SQLExecuteQueryOperator
from airflow.providers.snowflake.hooks.snowflake import SnowflakeHook
from airflow.sdk import TaskGroup, dag, get_current_context, task

URL_TRAJETS = "https://d37ci6vzurychx.cloudfront.net/trip-data/{fichier}"
STAGE = "NYC_TAXI.RAW.TLC_STAGE"
TABLE = "NYC_TAXI.RAW.YELLOW_TRIPDATA"
CONN_ID = "snowflake_nyc_taxi"


def executer(fichier: str) -> SQLExecuteQueryOperator:
    """Une tâche = un fichier SQL (chemin relatif à include/sql), nommée d'après le fichier."""
    return SQLExecuteQueryOperator(
        task_id=Path(fichier).stem,
        conn_id=CONN_ID,
        sql=fichier,
        split_statements=True,  # DELETE puis INSERT, ou plusieurs CREATE dans un même fichier
    )


def controler(fichier: str) -> SQLCheckOperator:
    """Contrôle : la requête renvoie une ligne ; une valeur fausse fait échouer la tâche."""
    return SQLCheckOperator(
        task_id=f"controle_{Path(fichier).stem}",
        conn_id=CONN_ID,
        sql=fichier,
        retries=0,  # relancer un contrôle ne change pas les données
    )


@dag(
    dag_id="nyc_taxi_mensuel",
    schedule="@monthly",
    start_date=pendulum.datetime(2025, 1, 1, tz="UTC"),
    end_date=pendulum.datetime(2025, 3, 1, tz="UTC"),
    catchup=True,          # un run par mois entre start_date et end_date
    max_active_runs=1,     # un mois à la fois, dans l'ordre
    max_active_tasks=3,    # le poste manque de mémoire : peu de tâches en parallèle
    tags=["nyc_taxi"],
    default_args={"retries": 2, "retry_delay": pendulum.duration(minutes=5)},
    template_searchpath="/usr/local/airflow/include/sql",
    params={
        "max_trip_distance_miles": 100,   # int_trips__flagged
        "max_trip_duration_min": 180,     # int_trips__flagged
        "start_month": "2025-01-01",      # dim_date
        "end_month": "2025-04-01",        # dim_date
        "max_pct_rejected": 10,           # controles/int_trop_ecartes
    },
)
def nyc_taxi_mensuel():

    @task
    def nom_du_fichier() -> str:
        mois = get_current_context()["logical_date"].strftime("%Y-%m")  # "2025-01" pour le run du 1er janvier
        return f"yellow_tripdata_{mois}.parquet"

    @task
    def verifier_disponibilite(fichier: str) -> str:
        url = URL_TRAJETS.format(fichier=fichier)
        requests.head(url, timeout=30).raise_for_status()  # 403/404 si le mois n'est pas publié
        return url

    @task
    def telecharger_et_deposer(url: str) -> str:
        # Une seule tâche : deux tâches peuvent tourner sur deux machines qui ne partagent pas /tmp.
        destination = Path("/tmp") / url.rsplit("/", 1)[-1]
        try:
            with requests.get(url, stream=True, timeout=120) as reponse:
                reponse.raise_for_status()
                with destination.open("wb") as f:
                    for morceau in reponse.iter_content(chunk_size=8 * 1024 * 1024):
                        f.write(morceau)
            # Mêmes options qu'au jour 2 : racine du stage, nom exact conservé, pas de renvoi.
            resultat = SnowflakeHook(snowflake_conn_id=CONN_ID).run(
                f"PUT 'file://{destination}' @{STAGE} AUTO_COMPRESS=FALSE OVERWRITE=FALSE",
                handler=lambda cur: cur.fetchall(),
            )
            print("PUT :", resultat[0][6])  # UPLOADED ou SKIPPED
        finally:
            destination.unlink(missing_ok=True)  # le disque du conteneur est limité
        return destination.name

    @task
    def copier_dans_la_table(fichier: str) -> None:
        hook = SnowflakeHook(snowflake_conn_id=CONN_ID)
        resultat = hook.run(
            f"""
            COPY INTO {TABLE}
            FROM @{STAGE}
            FILES = ('{fichier}')
            FILE_FORMAT = (FORMAT_NAME = NYC_TAXI.RAW.PARQUET_FF)
            MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
            INCLUDE_METADATA = (_source_file = METADATA$FILENAME, _loaded_at = METADATA$START_SCAN_TIME)
            ON_ERROR = ABORT_STATEMENT
            """,
            handler=lambda cur: cur.fetchall(),
        )
        for ligne in resultat:
            print("COPY :", ligne[:4] if len(ligne) > 3 else ligne[0])  # LOADED ou LOAD_SKIPPED
        lignes = hook.get_first(f"SELECT COUNT(*) FROM {TABLE} WHERE _source_file = %(f)s", parameters={"f": fichier})[0]
        print(f"{TABLE} contient {lignes:,} lignes issues de {fichier}")

    chargement = copier_dans_la_table(telecharger_et_deposer(verifier_disponibilite(nom_du_fichier())))
    controle_raw = controler("controles/raw_mois_charge.sql")
    tables = executer("00_tables.sql")

    # Ordre déduit des FROM/JOIN : un fichier passe après ceux qui créent les tables qu'il lit.
    with TaskGroup("staging") as staging:
        [executer(f"staging/{nom}.sql") for nom in ("codes_tlc", "stg_tlc__taxi_zones", "stg_tlc__yellow_trips")]

    with TaskGroup("intermediate") as intermediate:
        (
            executer("intermediate/int_trips__flagged.sql")
            >> controler("controles/int_trop_ecartes.sql")
            >> executer("intermediate/int_trips__enriched.sql")
            >> controler("controles/int_pas_de_doublon.sql")
        )

    with TaskGroup("marts") as marts:
        dimensions = [executer(f"marts/{nom}.sql") for nom in ("dim_date", "dim_payment_type", "dim_rate_code", "dim_vendor", "dim_zone")]
        faits = executer("marts/fct_trips.sql")
        analyses = [executer(f"marts/{nom}.sql") for nom in ("mart_daily_revenue", "mart_zone_hourly_demand")]
        for analyse in analyses:
            analyse.set_upstream(dimensions + [faits])
        executer("marts/mart_data_quality.sql")  # ne lit que INT_TRIPS__FLAGGED

    chargement >> controle_raw >> tables >> staging >> intermediate >> marts


nyc_taxi_mensuel()
