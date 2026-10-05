-- =============================================================================
-- 01_infra.sql — Entrepôt NYC_TAXI : rôle, warehouse, base, schémas, droits,
-- utilisateur de service.
--
-- Exécuté UNE fois par un humain dans Snowsight (bouton « Run All »), avec un
-- compte qui possède USERADMIN et SYSADMIN (ACCOUNTADMIN les possède).
-- Rejouable : IF NOT EXISTS partout, et les GRANT sont idempotents (redonner
-- un droit déjà donné ne fait rien).
--
-- Principe : chaque rôle système ne fait que son métier.
--   USERADMIN : crée les rôles et les utilisateurs
--   SYSADMIN  : crée le warehouse, la base, les schémas et en reste propriétaire
--   TRANSFORMER (rôle des outils) : crée et possède les tables, vues, stage,
--     formats de fichier ; ne peut ni créer de schéma, ni supprimer la base.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. Rôle des outils (USERADMIN)
-- -----------------------------------------------------------------------------
USE ROLE USERADMIN;

CREATE ROLE IF NOT EXISTS TRANSFORMER
    COMMENT = 'Rôle des outils (script Python, Airflow) : chargement RAW et transformations';

-- Rattacher le rôle à SYSADMIN : sinon les objets créés par TRANSFORMER
-- échappent aux administrateurs (SYSADMIN hérite des droits de TRANSFORMER).
GRANT ROLE TRANSFORMER TO ROLE SYSADMIN;


-- -----------------------------------------------------------------------------
-- 2. Warehouse, base, schémas (SYSADMIN, qui en reste propriétaire)
-- -----------------------------------------------------------------------------
USE ROLE SYSADMIN;

CREATE WAREHOUSE IF NOT EXISTS NYC_TAXI_WH
    WAREHOUSE_SIZE      = 'XSMALL'   -- la plus petite taille : 1 crédit/heure au plus
    AUTO_SUSPEND        = 60         -- s'arrête après 60 s sans requête
    AUTO_RESUME         = TRUE       -- redémarre seul à la requête suivante
    INITIALLY_SUSPENDED = TRUE       -- ne consomme rien à la création
    COMMENT = 'Calcul du projet NYC Taxi';

-- IF NOT EXISTS ne modifie pas un warehouse déjà créé : on réimpose les
-- réglages pour que relancer le script remette toujours la bonne configuration.
ALTER WAREHOUSE NYC_TAXI_WH SET
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND   = 60
    AUTO_RESUME    = TRUE;

CREATE DATABASE IF NOT EXISTS NYC_TAXI
    COMMENT = 'Entrepôt Hudson Cab Partners : trajets des taxis jaunes (TLC)';

CREATE SCHEMA IF NOT EXISTS NYC_TAXI.RAW          COMMENT = 'Bronze : copie fidèle des fichiers TLC';
CREATE SCHEMA IF NOT EXISTS NYC_TAXI.STAGING      COMMENT = 'Argent : colonnes renommées et typées (vues)';
CREATE SCHEMA IF NOT EXISTS NYC_TAXI.INTERMEDIATE COMMENT = 'Trajets étiquetés, puis valides et enrichis';
CREATE SCHEMA IF NOT EXISTS NYC_TAXI.MARTS        COMMENT = 'Or : faits, dimensions, tables d''analyse';


-- -----------------------------------------------------------------------------
-- 3. Droits minimaux du rôle des outils (SYSADMIN, propriétaire des objets)
-- -----------------------------------------------------------------------------
-- Utiliser le warehouse (USAGE suffit pour le réveil automatique ; pas
-- d'OPERATE ni de MODIFY : les outils ne changent ni la taille ni les réglages).
GRANT USAGE ON WAREHOUSE NYC_TAXI_WH TO ROLE TRANSFORMER;

-- Entrer dans la base (pas de CREATE SCHEMA : les 4 schémas sont fixés ici).
GRANT USAGE ON DATABASE NYC_TAXI TO ROLE TRANSFORMER;

-- RAW : tables, stage interne et formats de fichier pour le chargement.
GRANT USAGE, CREATE TABLE, CREATE STAGE, CREATE FILE FORMAT
    ON SCHEMA NYC_TAXI.RAW TO ROLE TRANSFORMER;

-- Les trois couches de transformation : tables et vues des fichiers SQL fournis.
GRANT USAGE, CREATE TABLE, CREATE VIEW ON SCHEMA NYC_TAXI.STAGING      TO ROLE TRANSFORMER;
GRANT USAGE, CREATE TABLE, CREATE VIEW ON SCHEMA NYC_TAXI.INTERMEDIATE TO ROLE TRANSFORMER;
GRANT USAGE, CREATE TABLE, CREATE VIEW ON SCHEMA NYC_TAXI.MARTS        TO ROLE TRANSFORMER;

-- Pas de GRANT SELECT/INSERT ON ALL/FUTURE TABLES : TRANSFORMER crée lui-même
-- toutes les tables et vues, il en est donc propriétaire et a tous les droits
-- dessus. Les donner en plus ne servirait à rien.


-- -----------------------------------------------------------------------------
-- 4. Utilisateur de service (USERADMIN)
-- -----------------------------------------------------------------------------
USE ROLE USERADMIN;

-- TYPE = SERVICE : pas de mot de passe possible, pas de MFA, pas de connexion
-- à Snowsight ; authentification par paire de clés uniquement.
-- La clé publique n'est PAS dans ce script : elle est propre à chaque poste et
-- s'enregistre ensuite avec ALTER USER ... SET RSA_PUBLIC_KEY (voir README).
CREATE USER IF NOT EXISTS AIRFLOW_SVC
    TYPE              = SERVICE
    DEFAULT_ROLE      = TRANSFORMER
    DEFAULT_WAREHOUSE = NYC_TAXI_WH
    DEFAULT_NAMESPACE = NYC_TAXI.RAW
    COMMENT = 'Compte de service du script de chargement et d''Airflow';

GRANT ROLE TRANSFORMER TO USER AIRFLOW_SVC;

-- L'humain qui exécute ce script reçoit aussi TRANSFORMER, pour créer les
-- objets RAW au jour 2 sous ce rôle (USE ROLE TRANSFORMER dans Snowsight).
-- CURRENT_USER() évite d'écrire un nom d'utilisateur personnel dans le dépôt.
SET utilisateur_courant = CURRENT_USER();
GRANT ROLE TRANSFORMER TO USER IDENTIFIER($utilisateur_courant);
