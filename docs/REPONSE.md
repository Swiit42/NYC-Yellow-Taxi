# Réponse à la direction d'Hudson Cab Partners

## La question

Où et quand la demande de taxis jaunes est-elle la plus forte à New York, et combien rapporte un trajet selon la zone, l'heure et le mode de paiement ?

## La requête

Les créneaux les plus demandés (zone de prise en charge × heure × semaine ou week-end), avec ce que rapporte un trajet :

```sql
SELECT
    pickup_zone_name                         AS zone,
    pickup_borough                           AS arrondissement,
    pickup_hour                              AS heure,
    IFF(is_weekend, 'week-end', 'semaine')   AS type_de_jour,
    avg_trips_per_day                        AS trajets_par_jour,
    avg_revenue_per_trip                     AS recette_moyenne_usd,
    avg_distance_miles                       AS distance_moyenne_miles,
    avg_tip_rate_pct_card                    AS pourboire_carte_pct,
    revenue_per_hour_driven                  AS recette_par_heure_roulee_usd
FROM NYC_TAXI.MARTS.MART_ZONE_HOURLY_DEMAND
WHERE pickup_zone_name IS NOT NULL
ORDER BY avg_trips_per_day DESC
LIMIT 10;
```

Le mode de paiement n'est pas dans cette table : il se lit dans la table de faits.

```sql
SELECT
    p.payment_type_label                               AS mode_de_paiement,
    COUNT(*)                                           AS trajets,
    ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 1)   AS part_pct,
    ROUND(AVG(f.total_amount), 2)                      AS recette_moyenne_usd,
    ROUND(AVG(f.tip_amount), 2)                        AS pourboire_moyen_usd
FROM NYC_TAXI.MARTS.FCT_TRIPS f
LEFT JOIN NYC_TAXI.MARTS.DIM_PAYMENT_TYPE p USING (payment_type_key)
GROUP BY 1
ORDER BY trajets DESC;
```

## Le résultat : les 10 premières lignes

| Zone | Heure | Jour | Trajets par jour | Recette moyenne | Distance | Pourboire (carte) | Recette par heure roulée |
|---|---|---|---|---|---|---|---|
| East Village | 0 h | week-end | 738 | 22,84 $ | 2,3 mi | 24,7 % | 113,75 $ |
| East Village | 1 h | week-end | 726 | 22,11 $ | 2,4 mi | 24,5 % | 109,36 $ |
| Midtown Center | 18 h | semaine | 596 | 24,98 $ | 1,9 mi | 27,8 % | 106,77 $ |
| Midtown Center | 17 h | semaine | 572 | 30,06 $ | 2,0 mi | 27,6 % | 115,24 $ |
| West Village | 0 h | week-end | 559 | 23,14 $ | 2,3 mi | 25,4 % | 108,21 $ |
| Midtown Center | 20 h | semaine | 535 | 22,81 $ | 2,2 mi | 27,0 % | 107,93 $ |
| West Village | 1 h | week-end | 519 | 22,57 $ | 2,4 mi | 24,8 % | 105,77 $ |
| East Village | 2 h | week-end | 519 | 22,00 $ | 2,5 mi | 25,1 % | 117,25 $ |
| Midtown Center | 19 h | semaine | 512 | 24,14 $ | 2,0 mi | 28,2 % | 113,12 $ |
| Midtown Center | 21 h | semaine | 494 | 23,01 $ | 2,3 mi | 27,2 % | 108,84 $ |

Par mode de paiement :

| Mode de paiement | Part des trajets | Recette moyenne | Pourboire moyen |
|---|---|---|---|
| Carte bancaire | 71,3 % | 28,32 $ | 4,14 $ |
| Flex Fare | 17,0 % | 24,35 $ | 0,44 $ |
| Espèces | 10,2 % | 23,70 $ | 0,00 $ (non enregistré) |
| Litige | 1,1 % | 35,21 $ | — |
| Gratuit | 0,4 % | 27,35 $ | — |

À l'échelle de la ville, la demande culmine à 18 h (environ 8 200 trajets par jour en moyenne) et touche son point bas à 4 h (moins de 800). Les aéroports rapportent le plus par trajet : 81 $ en moyenne au départ de JFK et 71 $ au départ de LaGuardia, contre 20 à 27 $ dans Manhattan.

## Ce qu'il faut en retenir

1. La demande se concentre dans deux créneaux de Manhattan : les sorties du vendredi et du samedi soir, de minuit à 2 h, à East Village et West Village, et la fin de journée en semaine, de 17 h à 21 h, à Midtown Center.
2. Ces trajets sont courts (environ 2 miles) et rapportent 22 à 30 $ chacun, mais ils s'enchaînent : un taxi y gagne 105 à 117 $ par heure de conduite. Un trajet depuis JFK rapporte trois à quatre fois plus, mais il est moins fréquent.
3. Sept trajets sur dix sont payés par carte, et ce sont eux qui rapportent le plus (28 $ en moyenne, pourboire compris). Les paiements en espèces ne laissent aucune trace du pourboire.

## Les limites

- **Période** : janvier à mars 2025 seulement, soit un hiver. L'été, les touristes et la météo peuvent déplacer la demande.
- **Trajets écartés** : 7,3 % des trajets (815 648 sur 11 198 026) sont exclus pour durée, distance, montant ou date anormaux, ou parce qu'ils sont en double. Le détail figure dans `MARTS.MART_DATA_QUALITY`.
- **Zones inconnues** : 0,22 % des trajets valides partent d'une zone inconnue (codes 264 et 265). Ils comptent dans le total mais pas dans le classement des zones.
- **Pourboires** : ils ne sont enregistrés que pour les paiements par carte. Pour les autres modes, le pourboire réel est inconnu, pas nul.
- **Moyenne par jour** : elle divise les trajets d'un créneau par le nombre de jours où ce créneau a eu au moins un trajet. Elle est donc un peu surestimée pour les zones peu actives, mais pas pour celles du classement.
- **Demande servie** : les données ne comptent que les trajets réalisés. La demande non servie (clients sans taxi) et les VTC (Uber, Lyft) n'y figurent pas.
