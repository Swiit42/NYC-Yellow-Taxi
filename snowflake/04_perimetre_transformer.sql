-- =============================================================================
-- 04_perimetre_transformer.sql — Prouver que le rôle des outils (TRANSFORMER)
-- ne peut pas sortir de son périmètre.
--
-- À lancer dans Snowsight (Run All). Chaque tentative interdite est attrapée :
-- le bloc renvoie une ligne par test, « refusé » attendu partout.
--
-- USE SECONDARY ROLES NONE est indispensable : dans Snowsight, votre utilisateur
-- garde par défaut ses autres rôles (ACCOUNTADMIN…) en rôles secondaires, et
-- plusieurs tests réussiraient grâce à eux, pas grâce à TRANSFORMER.
-- =============================================================================
USE ROLE TRANSFORMER;
USE SECONDARY ROLES NONE;
USE WAREHOUSE NYC_TAXI_WH;

-- 1. Ce que le rôle a le droit de faire
SHOW GRANTS TO ROLE TRANSFORMER;

-- 2. Ce qu'il n'a pas le droit de faire
EXECUTE IMMEDIATE $$
DECLARE
    resultat VARCHAR DEFAULT '';
BEGIN
    BEGIN CREATE DATABASE TEST_INTRUS;
          resultat := resultat || 'AUTORISÉ !! créer une base\n';
    EXCEPTION WHEN OTHER THEN resultat := resultat || 'refusé : créer une base\n'; END;

    BEGIN CREATE SCHEMA NYC_TAXI.TEST_INTRUS;
          resultat := resultat || 'AUTORISÉ !! créer un schéma\n';
    EXCEPTION WHEN OTHER THEN resultat := resultat || 'refusé : créer un schéma\n'; END;

    BEGIN CREATE WAREHOUSE TEST_INTRUS WITH WAREHOUSE_SIZE = XSMALL INITIALLY_SUSPENDED = TRUE;
          resultat := resultat || 'AUTORISÉ !! créer un warehouse\n';
    EXCEPTION WHEN OTHER THEN resultat := resultat || 'refusé : créer un warehouse\n'; END;

    BEGIN ALTER WAREHOUSE NYC_TAXI_WH SET WAREHOUSE_SIZE = MEDIUM;
          resultat := resultat || 'AUTORISÉ !! agrandir le warehouse\n';
    EXCEPTION WHEN OTHER THEN resultat := resultat || 'refusé : agrandir le warehouse\n'; END;

    BEGIN CREATE USER TEST_INTRUS;
          resultat := resultat || 'AUTORISÉ !! créer un utilisateur\n';
    EXCEPTION WHEN OTHER THEN resultat := resultat || 'refusé : créer un utilisateur\n'; END;

    BEGIN CREATE ROLE TEST_INTRUS;
          resultat := resultat || 'AUTORISÉ !! créer un rôle\n';
    EXCEPTION WHEN OTHER THEN resultat := resultat || 'refusé : créer un rôle\n'; END;

    BEGIN GRANT USAGE ON DATABASE NYC_TAXI TO ROLE PUBLIC;
          resultat := resultat || 'AUTORISÉ !! partager la base avec tout le monde\n';
    EXCEPTION WHEN OTHER THEN resultat := resultat || 'refusé : partager la base avec tout le monde\n'; END;

    BEGIN SELECT COUNT(*) FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY;
          resultat := resultat || 'AUTORISÉ !! lire la consommation du compte\n';
    EXCEPTION WHEN OTHER THEN resultat := resultat || 'refusé : lire la consommation du compte\n'; END;

    RETURN resultat;
END;
$$;

-- 3. Prendre un rôle d'administration : doit échouer
--    (Insufficient privileges / Requested role is not assigned). Dernière
--    instruction du fichier, car Run All s'arrête à la première erreur.
USE ROLE ACCOUNTADMIN;
