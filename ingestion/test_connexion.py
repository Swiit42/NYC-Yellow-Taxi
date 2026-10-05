"""Vérifie que l'utilisateur de service se connecte à Snowflake avec sa clé privée (jour 1).

Usage :
    export SNOWFLAKE_ACCOUNT=ORGANISATION-COMPTE
    python ingestion/test_connexion.py

Aucun secret dans ce fichier : le compte est lu dans une variable d'environnement,
la clé privée dans un fichier hors du dépôt (~/.ssh/snowflake/rsa_key.p8 par défaut).
"""
import os

import snowflake.connector
from cryptography.hazmat.primitives import serialization

# Lecture de la clé privée PKCS#8 non chiffrée générée par openssl
chemin_cle = os.path.expanduser(os.environ.get("SNOWFLAKE_PRIVATE_KEY_PATH", "~/.ssh/snowflake/rsa_key.p8"))
with open(chemin_cle, "rb") as f:
    cle_privee = serialization.load_pem_private_key(f.read(), password=None)

conn = snowflake.connector.connect(
    account=os.environ["SNOWFLAKE_ACCOUNT"],                     # obligatoire : ex. CQGSTAP-LX13853
    user=os.environ.get("SNOWFLAKE_USER", "AIRFLOW_SVC"),
    private_key=cle_privee,
    role=os.environ.get("SNOWFLAKE_ROLE", "TRANSFORMER"),
    warehouse=os.environ.get("SNOWFLAKE_WAREHOUSE", "NYC_TAXI_WH"),
)
try:
    utilisateur, role, warehouse = conn.cursor().execute(
        "SELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE()"
    ).fetchone()
    print(f"Connecté : utilisateur={utilisateur} | rôle={role} | warehouse={warehouse}")
finally:
    conn.close()
