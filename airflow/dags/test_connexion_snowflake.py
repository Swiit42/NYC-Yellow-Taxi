"""Preuve que la connexion `snowflake_nyc_taxi` (définie dans .env) fonctionne.

Sans planification : c'est le seul DAG qu'on lance avec le bouton Trigger.
Le log de la tâche doit afficher AIRFLOW_SVC, TRANSFORMER et NYC_TAXI_WH.
"""
import pendulum
from airflow.providers.snowflake.hooks.snowflake import SnowflakeHook
from airflow.sdk import dag, task


@dag(
    schedule=None,
    start_date=pendulum.datetime(2025, 1, 1, tz="UTC"),
    catchup=False,
    tags=["nyc_taxi", "test"],
    default_args={"retries": 2},
)
def test_connexion_snowflake():
    @task
    def qui_suis_je():
        utilisateur, role, warehouse = SnowflakeHook(snowflake_conn_id="snowflake_nyc_taxi").get_first(
            "SELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE()"
        )
        print(f"Connecté : utilisateur={utilisateur} | rôle={role} | warehouse={warehouse}")

    qui_suis_je()


test_connexion_snowflake()
