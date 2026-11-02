-- =============================================================================
-- 03_comptage_anomalies.sql — Recompter les trajets anormaux de janvier 2025
-- directement dans RAW, puis comparer avec MARTS.MART_DATA_QUALITY.
--
-- Chaque règle est comptée SÉPARÉMENT : un trajet peut enfreindre plusieurs
-- règles. MART_DATA_QUALITY n'attribue qu'UNE raison par trajet (la première
-- qui échoue, dans l'ordre de int_trips__flagged.sql) : nos comptes par règle
-- sont donc supérieurs ou égaux aux siens, mais le total des trajets anormaux
-- (au moins une règle) doit être identique.
-- =============================================================================
USE ROLE TRANSFORMER;
USE WAREHOUSE NYC_TAXI_WH;

WITH janvier AS (
    SELECT
        tpep_pickup_datetime  AS pickup_at,
        tpep_dropoff_datetime AS dropoff_at,
        trip_distance, fare_amount, total_amount, pulocationid, dolocationid
    FROM NYC_TAXI.RAW.YELLOW_TRIPDATA
    WHERE _source_file = 'yellow_tripdata_2025-01.parquet'
),
regles AS (
    SELECT
        pickup_at IS NULL OR dropoff_at IS NULL                           AS timestamp_null,
        dropoff_at <= pickup_at                                           AS duration_non_positive,
        DATEDIFF('second', pickup_at, dropoff_at) > 180 * 60              AS duration_too_long,
        DATE_TRUNC('month', pickup_at) <> '2025-01-01'::date              AS pickup_outside_file_month,
        trip_distance <= 0 OR trip_distance > 100                         AS distance_out_of_range,
        fare_amount < 0 OR total_amount <= 0                              AS amount_non_positive,
        pulocationid IS NULL OR dolocationid IS NULL                      AS zone_null
    FROM janvier
)
SELECT 'timestamp_null' AS regle, COUNT_IF(timestamp_null) AS nos_comptes FROM regles
UNION ALL SELECT 'duration_non_positive',     COUNT_IF(duration_non_positive)     FROM regles
UNION ALL SELECT 'duration_too_long',         COUNT_IF(duration_too_long)         FROM regles
UNION ALL SELECT 'pickup_outside_file_month', COUNT_IF(pickup_outside_file_month) FROM regles
UNION ALL SELECT 'distance_out_of_range',     COUNT_IF(distance_out_of_range)     FROM regles
UNION ALL SELECT 'amount_non_positive',       COUNT_IF(amount_non_positive)       FROM regles
UNION ALL SELECT 'zone_null',                 COUNT_IF(zone_null)                 FROM regles
UNION ALL SELECT 'TOTAL au moins une règle',  COUNT_IF(
    COALESCE(timestamp_null, FALSE) OR COALESCE(duration_non_positive, FALSE) OR COALESCE(duration_too_long, FALSE)
    OR COALESCE(pickup_outside_file_month, FALSE) OR COALESCE(distance_out_of_range, FALSE)
    OR COALESCE(amount_non_positive, FALSE) OR COALESCE(zone_null, FALSE)) FROM regles;

-- Ce que dit le rapport qualité pour le même mois (une seule raison par trajet)
SELECT status, nb_rows, pct_of_file
FROM NYC_TAXI.MARTS.MART_DATA_QUALITY
WHERE source_file = 'yellow_tripdata_2025-01.parquet'
ORDER BY nb_rows DESC;
