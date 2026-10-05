# Fiche source — Trajets des taxis jaunes de New York (TLC Yellow Taxi Trip Records)

## Identité

| Rubrique | Réponse |
|---|---|
| Nom de la source | Yellow Taxi Trip Records |
| Producteur des données | NYC Taxi and Limousine Commission (TLC), à partir des enregistrements transmis par les fournisseurs de taximètres (TPEP) |
| Adresse (URL) | `https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_AAAA-MM.parquet` (page de référence : https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page) |
| Accès (public, authentifié) | public, sans authentification (HTTPS, réponse `200` vérifiée le 05/10/2026) |
| Format du fichier | Apache Parquet (colonnes typées, compressé) : 1 fichier par mois |
| Fréquence de publication | mensuelle |
| Délai entre la période couverte et la publication | environ deux mois : « Trip data is published monthly on this website, typically with a two-month delay » (page TLC) |
| Dictionnaire de données | https://www.nyc.gov/assets/tlc/downloads/pdf/data_dictionary_trip_records_yellow.pdf (édition du 18 mars 2025) |

## Volume mesuré

| Fichier | Taille | Nombre de lignes | Nombre de colonnes | Outil et commande utilisés |
|---|---|---|---|---|
| `yellow_tripdata_2025-01.parquet` | 59 158 238 octets (56,4 Mio) | 3 475 226 | 20 | `python ingestion/explorer_source.py data/yellow_tripdata_2025-01.parquet` (DuckDB `COUNT(*)` + métadonnées pyarrow) ; taille : `ls -l` |
| `yellow_tripdata_2025-02.parquet` | 60 343 086 octets (57,5 Mio) | 3 577 543 | 20 | idem |
| `yellow_tripdata_2025-03.parquet` | 69 964 745 octets (66,7 Mio) | 4 145 257 | 20 | idem |
| **Total du périmètre** | **189 466 069 octets (180,7 Mio)** | **11 198 026** | | |

Le nombre de lignes lu dans les métadonnées du fichier (pied de page Parquet) et le `COUNT(*)` de DuckDB sont identiques.

## Colonnes

Types lus dans le schéma Parquet (`pyarrow.parquet.read_schema`), identiques pour les trois mois. Exemple : première ligne du fichier de janvier.

| Colonne | Type dans le fichier | Signification (dictionnaire TLC) | Exemple de valeur |
|---|---|---|---|
| `VendorID` | int32 | fournisseur du taximètre (code) | `1` |
| `tpep_pickup_datetime` | timestamp[us] (sans fuseau) | date et heure de mise en marche du compteur | `2025-01-01 00:18:38` |
| `tpep_dropoff_datetime` | timestamp[us] (sans fuseau) | date et heure d'arrêt du compteur | `2025-01-01 00:26:59` |
| `passenger_count` | int64 | nombre de passagers | `1` |
| `trip_distance` | double | distance parcourue en miles, selon le taximètre | `1.6` |
| `RatecodeID` | int64 | tarif en vigueur à la fin du trajet (code) | `1` |
| `store_and_fwd_flag` | string | trajet stocké dans le véhicule avant envoi, faute de connexion (`Y`/`N`) | `N` |
| `PULocationID` | int32 | zone TLC de prise en charge (→ `taxi_zone_lookup.csv`) | `229` |
| `DOLocationID` | int32 | zone TLC de dépose | `237` |
| `payment_type` | int64 | mode de paiement (code) | `1` |
| `fare_amount` | double | prix au compteur (temps et distance), USD | `10.0` |
| `extra` | double | suppléments divers | `3.5` |
| `mta_tax` | double | taxe MTA déclenchée selon le tarif | `0.5` |
| `tip_amount` | double | pourboire, **cartes bancaires uniquement** (pourboires en espèces absents) | `3.0` |
| `tolls_amount` | double | total des péages | `0.0` |
| `improvement_surcharge` | double | surtaxe d'amélioration, prélevée à la prise en charge | `1.0` |
| `total_amount` | double | montant total payé par le passager (hors pourboire en espèces) | `18.0` |
| `congestion_surcharge` | double | surtaxe de congestion de l'État de New York | `2.5` |
| `Airport_fee` | double | frais de prise en charge à LaGuardia et JFK. **Écrit avec une majuscule dans le fichier**, `airport_fee` dans le dictionnaire | `0.0` |
| `cbd_congestion_fee` | double | péage de la zone de congestion de Manhattan (MTA), depuis le 5 janvier 2025 | `0.0` |

## Codes

D'après le dictionnaire TLC (18 mars 2025). Effectifs mesurés sur janvier 2025.

| Colonne | Valeur | Signification | Lignes en janvier |
|---|---|---|---|
| `VendorID` | 1 | Creative Mobile Technologies, LLC | 753 671 |
| `VendorID` | 2 | Curb Mobility, LLC | 2 719 860 |
| `VendorID` | 6 | Myle Technologies Inc | 489 |
| `VendorID` | 7 | Helix | 1 206 |
| `RatecodeID` | 1 | Standard rate | 2 756 472 |
| `RatecodeID` | 2 | JFK | 94 420 |
| `RatecodeID` | 3 | Newark | 8 622 |
| `RatecodeID` | 4 | Nassau or Westchester | 7 092 |
| `RatecodeID` | 5 | Negotiated fare | 26 501 |
| `RatecodeID` | 6 | Group ride | 7 |
| `RatecodeID` | 99 | Null/unknown | 41 963 |
| `RatecodeID` | (vide) | non renseigné | 540 149 |
| `payment_type` | 0 | Flex Fare trip | 540 149 |
| `payment_type` | 1 | Credit card | 2 444 393 |
| `payment_type` | 2 | Cash | 390 429 |
| `payment_type` | 3 | No charge | 23 773 |
| `payment_type` | 4 | Dispute | 76 481 |
| `payment_type` | 5 | Unknown | 1 |
| `payment_type` | 6 | Voided trip | 0 |
| `store_and_fwd_flag` | Y | trajet stocké puis transmis | 7 646 |
| `store_and_fwd_flag` | N | trajet transmis directement | 2 927 431 |
| `store_and_fwd_flag` | (vide) | non renseigné | 540 149 |

## Ce qui a surpris

Mesures de janvier 2025, sauf mention contraire.

- **Un bloc de 540 149 trajets « Flex Fare » (`payment_type = 0`, 15,5 %) a cinq colonnes vides** : `passenger_count`, `RatecodeID`, `store_and_fwd_flag`, `congestion_surcharge` et `Airport_fee`. Ce sont exactement les mêmes lignes (même effectif). Ces colonnes ne sont donc pas « obligatoires » dans le fichier : RAW doit accepter les `NULL`.
- **Des dates hors du mois du fichier** : 22 prises en charge en dehors de janvier (de `2024-12-31 20:47` à `2025-02-01 00:00`). Le fichier de mars contient même un trajet daté du `2007-12-05`.
- **Des valeurs aberrantes** : 90 893 distances nulles ou négatives (max 276 423 miles), 144 118 tarifs négatifs (total min −901 $, max 863 380 $), 2 051 trajets dont l'arrivée précède ou égale le départ, 24 656 trajets à 0 passager.

Conséquence pour l'entrepôt : RAW garde tout tel quel (copie fidèle), et c'est `int_trips__flagged.sql` qui étiquette ces lignes.
