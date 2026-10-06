"""Charge un mois de trajets TLC (ou la liste des zones) dans la couche RAW de Snowflake.

Usage :
    python ingestion/charger_mois.py --month 2025-01     # trajets du mois
    python ingestion/charger_mois.py --zones             # liste des 265 zones

Étapes : télécharger le fichier -> le déposer sur le stage (PUT) -> le copier dans
la table (COPY INTO). Rejouable : relancer un mois déjà chargé n'ajoute aucune ligne,
car COPY INTO garde pendant 64 jours la liste des fichiers déjà chargés dans chaque
table et les ignore (statut LOAD_SKIPPED).
"""
import argparse
import re
from pathlib import Path

import requests

from connexion import connecter

URL_TRAJETS = "https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_{mois}.parquet"
URL_ZONES = "https://d37ci6vzurychx.cloudfront.net/misc/taxi_zone_lookup.csv"
DOSSIER = Path(__file__).resolve().parent.parent / "data"  # ignoré par Git
STAGE = "NYC_TAXI.RAW.TLC_STAGE"


def telecharger(url: str) -> Path:
    """Télécharge le fichier par morceaux (sans tout garder en mémoire). Ne refait rien s'il est déjà là."""
    DOSSIER.mkdir(exist_ok=True)
    destination = DOSSIER / url.rsplit("/", 1)[-1]
    if destination.exists():
        print(f"déjà téléchargé : {destination.name}")
        return destination
    print(f"téléchargement : {url}")
    with requests.get(url, stream=True, timeout=120) as reponse:
        reponse.raise_for_status()  # 403/404 si le fichier du mois n'est pas publié
        partiel = destination.with_suffix(".part")  # fichier final seulement si le téléchargement est complet
        with partiel.open("wb") as f:
            for morceau in reponse.iter_content(chunk_size=8 * 1024 * 1024):
                f.write(morceau)
        partiel.rename(destination)
    return destination


def charger(fichier: Path, table: str, format_fichier: str) -> None:
    conn = connecter()
    try:
        with conn.cursor() as cur:
            # PUT : dépôt à la racine du stage. AUTO_COMPRESS=FALSE garde le nom exact
            # (sinon .csv deviendrait .csv.gz et _source_file ne respecterait plus le contrat).
            # OVERWRITE=FALSE : un fichier déjà déposé n'est pas renvoyé.
            # as_posix() : chemin avec des / (sous Windows, PUT n'accepte pas les \) ;
            # les guillemets protègent les espaces du chemin.
            cur.execute(f"PUT 'file://{fichier.as_posix()}' @{STAGE} AUTO_COMPRESS=FALSE OVERWRITE=FALSE")
            print("PUT  :", cur.fetchone()[6])  # UPLOADED ou SKIPPED

            # COPY INTO : colonnes associées par leur nom (Airport_fee -> airport_fee) ;
            # colonnes techniques remplies par les métadonnées du chargement.
            cur.execute(f"""
                COPY INTO {table}
                FROM @{STAGE}
                FILES = ('{fichier.name}')
                FILE_FORMAT = (FORMAT_NAME = NYC_TAXI.RAW.{format_fichier})
                MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
                INCLUDE_METADATA = (_source_file = METADATA$FILENAME, _loaded_at = METADATA$START_SCAN_TIME)
                ON_ERROR = ABORT_STATEMENT
            """)
            for ligne in cur.fetchall():
                # 1 ligne par fichier (fichier, statut, lignes lues, lignes chargées...),
                # ou une seule colonne « Copy executed with 0 files processed. » si déjà chargé
                print("COPY :", ligne[:4] if len(ligne) > 3 else ligne[0])

            cur.execute(f"SELECT COUNT(*) FROM {table} WHERE _source_file = %s", (fichier.name,))
            print(f"{table} contient {cur.fetchone()[0]:,} lignes issues de {fichier.name}")
    finally:
        conn.close()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    groupe = parser.add_mutually_exclusive_group(required=True)
    groupe.add_argument("--month", help="mois à charger, au format AAAA-MM (ex. 2025-01)")
    groupe.add_argument("--zones", action="store_true", help="charger la liste des zones")
    args = parser.parse_args()

    if args.zones:
        charger(telecharger(URL_ZONES), "NYC_TAXI.RAW.TAXI_ZONE_LOOKUP", "CSV_FF")
    else:
        if not re.fullmatch(r"\d{4}-(0[1-9]|1[0-2])", args.month):
            parser.error("--month doit être au format AAAA-MM, par exemple 2025-01")
        charger(telecharger(URL_TRAJETS.format(mois=args.month)), "NYC_TAXI.RAW.YELLOW_TRIPDATA", "PARQUET_FF")


if __name__ == "__main__":
    main()
