-- Aucun trajet en double dans les trajets valides du mois : la clé trip_sk est unique.
SELECT COUNT(*) = COUNT(DISTINCT trip_sk)
FROM NYC_TAXI.INTERMEDIATE.INT_TRIPS__ENRICHED
WHERE source_file_month = '{{ ds }}'::date;
