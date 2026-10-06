"""Connexion Snowflake de l'utilisateur de service, partagée par les scripts d'ingestion.

Aucun secret ici : le compte vient de la variable d'environnement SNOWFLAKE_ACCOUNT,
la clé privée d'un fichier hors du dépôt (~/.ssh/snowflake/rsa_key.p8 par défaut).
"""
import os

import snowflake.connector
from cryptography.hazmat.primitives import serialization


def connecter() -> snowflake.connector.SnowflakeConnection:
    chemin_cle = os.path.expanduser(os.environ.get("SNOWFLAKE_PRIVATE_KEY_PATH", "~/.ssh/snowflake/rsa_key.p8"))
    with open(chemin_cle, "rb") as f:
        cle_privee = serialization.load_pem_private_key(f.read(), password=None)

    return snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],  # ex. ORGANISATION-COMPTE
        user=os.environ.get("SNOWFLAKE_USER", "AIRFLOW_SVC"),
        private_key=cle_privee,
        role=os.environ.get("SNOWFLAKE_ROLE", "TRANSFORMER"),
        warehouse=os.environ.get("SNOWFLAKE_WAREHOUSE", "NYC_TAXI_WH"),
        database="NYC_TAXI",
        schema="RAW",
    )
