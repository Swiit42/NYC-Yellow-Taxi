-- =============================================================================
-- 02_raw.sql — Couche RAW : formats de fichier, stage interne, tables du contrat.
--
-- Exécuté avec le rôle des outils TRANSFORMER, pour qu'il soit propriétaire des
-- objets (créés avec ACCOUNTADMIN, les outils ne les verraient pas).
-- Rejouable : IF NOT EXISTS sur le stage et les tables (un OR REPLACE viderait
-- les fichiers déposés, les données et l'historique de chargement).
-- =============================================================================
USE ROLE TRANSFORMER;
USE WAREHOUSE NYC_TAXI_WH;
USE SCHEMA NYC_TAXI.RAW;


-- -----------------------------------------------------------------------------
-- Formats de fichier : OR REPLACE sans risque, un format ne contient aucune donnée.
-- -----------------------------------------------------------------------------
-- Parquet porte le nom et le type de ses colonnes. USE_LOGICAL_TYPE est
-- indispensable : les dates TLC sont des entiers en microsecondes (type logique
-- Timestamp) ; sans cette option, Snowflake les lit mal (année 55 000 000).
CREATE OR REPLACE FILE FORMAT PARQUET_FF
    TYPE = PARQUET
    USE_LOGICAL_TYPE = TRUE
    COMMENT = 'Fichiers mensuels des trajets TLC';

-- CSV : PARSE_HEADER lit les noms de colonnes de la 1re ligne, indispensable
-- pour MATCH_BY_COLUMN_NAME. Les colonnes techniques n'existent pas dans le
-- fichier : on tolère l'écart de nombre de colonnes.
CREATE OR REPLACE FILE FORMAT CSV_FF
    TYPE = CSV
    PARSE_HEADER = TRUE
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
    COMMENT = 'Liste des zones TLC';


-- -----------------------------------------------------------------------------
-- Stage interne : zone de dépôt des fichiers dans Snowflake, avant COPY INTO.
-- Les fichiers y sont déposés à la racine : METADATA$FILENAME vaut alors le
-- nom nu du fichier (contrat de _source_file).
-- -----------------------------------------------------------------------------
CREATE STAGE IF NOT EXISTS TLC_STAGE
    COMMENT = 'Fichiers TLC déposés par PUT avant chargement';


-- -----------------------------------------------------------------------------
-- Tables du contrat. Types larges : NUMBER pour les codes et compteurs (une
-- valeur 1.0 d'un mois en double y entre sans perte), FLOAT pour les montants
-- et distances (un NUMBER sans échelle arrondirait 12.75 en 13).
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS YELLOW_TRIPDATA (
    vendorid               NUMBER,
    tpep_pickup_datetime   TIMESTAMP_NTZ,
    tpep_dropoff_datetime  TIMESTAMP_NTZ,
    passenger_count        NUMBER,
    trip_distance          FLOAT,
    ratecodeid             NUMBER,
    store_and_fwd_flag     VARCHAR,
    pulocationid           NUMBER,
    dolocationid           NUMBER,
    payment_type           NUMBER,
    fare_amount            FLOAT,
    extra                  FLOAT,
    mta_tax                FLOAT,
    tip_amount             FLOAT,
    tolls_amount           FLOAT,
    improvement_surcharge  FLOAT,
    total_amount           FLOAT,
    congestion_surcharge   FLOAT,
    airport_fee            FLOAT,
    cbd_congestion_fee     FLOAT,
    _source_file           VARCHAR,        -- rempli par METADATA$FILENAME
    _loaded_at             TIMESTAMP_NTZ   -- rempli par METADATA$START_SCAN_TIME
)
COMMENT = 'RAW : copie fidèle des fichiers Parquet mensuels de la TLC (1 ligne = 1 trajet)';

CREATE TABLE IF NOT EXISTS TAXI_ZONE_LOOKUP (
    locationid    NUMBER,
    borough       VARCHAR,
    zone          VARCHAR,
    service_zone  VARCHAR,
    _source_file  VARCHAR,
    _loaded_at    TIMESTAMP_NTZ
)
COMMENT = 'RAW : liste des 265 zones TLC (taxi_zone_lookup.csv)';
