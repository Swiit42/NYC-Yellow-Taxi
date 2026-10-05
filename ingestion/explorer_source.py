"""Mesure un fichier Parquet de trajets TLC pour remplir la fiche source (jour 1).

Usage : python explorer_source.py data/yellow_tripdata_2025-01.parquet [autres fichiers...]

Tout est lu par DuckDB directement dans le fichier : rien n'est chargé en entier en mémoire.
"""
import os
import sys

import duckdb
import pyarrow.parquet as pq


def explorer(chemin: str) -> None:
    nom = os.path.basename(chemin)
    taille_mo = os.path.getsize(chemin) / 1024 / 1024
    meta = pq.ParquetFile(chemin).metadata  # lu dans le pied de fichier, sans lire les données
    print(f"\n===== {nom}")
    print(f"taille : {taille_mo:.1f} Mo | lignes (métadonnées) : {meta.num_rows:,} | colonnes : {meta.num_columns}")

    # Schéma : nom et type de chaque colonne tels qu'écrits dans le fichier
    print("\n-- schéma")
    for champ in pq.read_schema(chemin):
        print(f"  {champ.name:<24} {champ.type}")

    con = duckdb.connect()
    src = f"read_parquet('{chemin}')"
    print(f"\nlignes (COUNT(*)) : {con.sql(f'SELECT COUNT(*) FROM {src}').fetchone()[0]:,}")

    print("\n-- exemple de ligne")
    print(con.sql(f"SELECT * FROM {src} LIMIT 1").df().T.to_string())

    # Valeurs prises par les colonnes de codes
    for col in ["VendorID", "RatecodeID", "payment_type", "store_and_fwd_flag"]:
        print(f"\n-- valeurs de {col}")
        print(con.sql(f"SELECT {col}, COUNT(*) AS nb FROM {src} GROUP BY 1 ORDER BY 1").df().to_string(index=False))

    # Valeurs nulles par colonne
    print("\n-- valeurs nulles par colonne")
    colonnes = [c.name for c in pq.read_schema(chemin)]
    nulls = ", ".join(f'COUNT(*) - COUNT("{c}") AS "{c}"' for c in colonnes)
    print(con.sql(f"SELECT {nulls} FROM {src}").df().T.to_string(header=False))

    # Anomalies visibles à l'œil (le mois attendu est lu dans le nom du fichier)
    mois = nom.split("_")[-1].replace(".parquet", "")  # ex. 2025-01
    print("\n-- anomalies")
    print(con.sql(f"""
        SELECT
            MIN(tpep_pickup_datetime)                                         AS pickup_min,
            MAX(tpep_pickup_datetime)                                         AS pickup_max,
            COUNT_IF(strftime(tpep_pickup_datetime, '%Y-%m') <> '{mois}')     AS pickup_hors_mois,
            COUNT_IF(tpep_dropoff_datetime <= tpep_pickup_datetime)           AS duree_negative_ou_nulle,
            COUNT_IF(trip_distance <= 0)                                      AS distance_nulle_ou_neg,
            MAX(trip_distance)                                                AS distance_max,
            COUNT_IF(fare_amount < 0)                                         AS tarif_negatif,
            COUNT_IF(total_amount <= 0)                                       AS total_nul_ou_neg,
            MIN(total_amount)                                                 AS total_min,
            MAX(total_amount)                                                 AS total_max,
            COUNT_IF(passenger_count = 0)                                     AS zero_passager
        FROM {src}
    """).df().T.to_string(header=False))


if __name__ == "__main__":
    for fichier in sys.argv[1:]:
        explorer(fichier)
