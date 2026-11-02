-- Le mois ne perd pas trop de trajets : la part de trajets écartés par les règles
-- de qualité reste sous le seuil du DAG (params.max_pct_rejected, en %).
SELECT COUNT_IF(rejection_reason IS NOT NULL) / COUNT(*) * 100 < {{ params.max_pct_rejected }}
FROM NYC_TAXI.INTERMEDIATE.INT_TRIPS__FLAGGED
WHERE source_file_month = '{{ ds }}'::date;
