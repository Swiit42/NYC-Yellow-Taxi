-- =============================================================================
-- 05_credits_consommes.sql — Crédits consommés par le warehouse du projet.
--
-- À lancer dans Snowsight avec ACCOUNTADMIN : ACCOUNT_USAGE n'est pas lisible
-- par le rôle des outils (voir 04_perimetre_transformer.sql). Les vues
-- ACCOUNT_USAGE ont jusqu'à 3 heures de retard.
-- =============================================================================
USE ROLE ACCOUNTADMIN;

-- Crédits par jour (calcul + services cloud)
SELECT
    DATE_TRUNC('day', start_time)::date       AS jour,
    ROUND(SUM(credits_used_compute), 4)       AS credits_calcul,
    ROUND(SUM(credits_used_cloud_services), 4) AS credits_services_cloud,
    ROUND(SUM(credits_used), 4)               AS credits_total
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE warehouse_name = 'NYC_TAXI_WH'
GROUP BY 1
ORDER BY 1;

-- Total du projet, et ce qu'il représente en dollars (prix indicatif : vérifier
-- le prix du crédit de votre édition et de votre région dans Admin > Billing)
SELECT
    ROUND(SUM(credits_used), 4)      AS credits_total,
    ROUND(SUM(credits_used) * 2, 2)  AS cout_usd_a_2_dollars_le_credit
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE warehouse_name = 'NYC_TAXI_WH';

-- Requêtes les plus longues du rôle des outils (où part le temps de calcul)
SELECT
    LEFT(query_text, 80)                 AS requete,
    ROUND(total_elapsed_time / 1000, 1)  AS duree_s,
    ROUND(bytes_scanned / POWER(1024, 3), 2) AS go_lus
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE role_name = 'TRANSFORMER'
  AND warehouse_name = 'NYC_TAXI_WH'
ORDER BY total_elapsed_time DESC
LIMIT 10;
