"""Exécute un fichier SQL versionné avec l'utilisateur de service (rôle TRANSFORMER).

Usage : python ingestion/executer_sql.py snowflake/02_raw.sql

Sert aux scripts de la couche RAW, qui doivent être exécutés par le rôle des outils
pour qu'il soit propriétaire des objets. Le script d'infrastructure (01_infra.sql)
ne passe PAS par ici : il demande les rôles d'administration, donc un humain.
"""
import sys

from connexion import connecter

with open(sys.argv[1], encoding="utf-8") as f:
    script = f.read()

conn = connecter()
try:
    # execute_string découpe le fichier en instructions et les exécute dans l'ordre
    for curseur in conn.execute_string(script, remove_comments=True):
        print(f"OK  {curseur.query.strip().splitlines()[0][:80]}  ->  {curseur.fetchone()}")
finally:
    conn.close()
