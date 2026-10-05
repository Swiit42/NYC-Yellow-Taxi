-- =============================================================================
-- Vérifications après 01_infra.sql (Snowsight, rôle ACCOUNTADMIN ou SECURITYADMIN)
-- =============================================================================

-- Warehouse : taille XSMALL, auto_suspend 60, auto_resume true, état SUSPENDED
SHOW WAREHOUSES LIKE 'NYC_TAXI_WH';

-- Base et schémas, propriétaire SYSADMIN
SHOW SCHEMAS IN DATABASE NYC_TAXI;

-- Ce que le rôle des outils a le droit de faire (rien de plus que la section 3)
SHOW GRANTS TO ROLE TRANSFORMER;

-- Qui possède le rôle : SYSADMIN, AIRFLOW_SVC, l'humain qui a lancé le script
SHOW GRANTS OF ROLE TRANSFORMER;

-- L'utilisateur de service : TYPE = SERVICE, rôle et warehouse par défaut,
-- RSA_PUBLIC_KEY_FP renseigné une fois la clé enregistrée
DESC USER AIRFLOW_SVC;
