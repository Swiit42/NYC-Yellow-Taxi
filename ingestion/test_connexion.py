"""Vérifie que l'utilisateur de service se connecte à Snowflake avec sa clé privée (jour 1).

Usage :
    export SNOWFLAKE_ACCOUNT=ORGANISATION-COMPTE
    python ingestion/test_connexion.py
"""
from connexion import connecter

conn = connecter()
try:
    utilisateur, role, warehouse = conn.cursor().execute(
        "SELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE()"
    ).fetchone()
    print(f"Connecté : utilisateur={utilisateur} | rôle={role} | warehouse={warehouse}")
finally:
    conn.close()
