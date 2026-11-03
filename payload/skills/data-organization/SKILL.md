---
name: data-organization
description: Rangement des données scrappées — structure de projet, formats, base SQLite ou DuckDB, déduplication, traçabilité et contrôle qualité.
---

# Organisation des données

## Structure de chaque projet

```text
scraping/<AAAA-MM-JJ>_<sujet>/
├── README.md        source, méthode, schéma, couverture, limites
├── config/          urls.txt, selecteurs.json, schema.json
├── state.db         file d'URL et résultats (moteur)
├── raw/             réponses brutes compressées, jamais modifiées
├── clean/           données nettoyées et validées
├── rejects/         lignes refusées, avec la raison
├── exports/         livrables : Parquet, CSV, NDJSON, Excel
├── scripts/         code du projet
└── manifest.json    paramètres et compteurs
```

Crée le dossier racine `scraping/` dans le répertoire courant, sauf indication contraire. Jamais de `data2_final.csv` : on versionne par date.

## Choisir le stockage

| Volume ou besoin | Format |
|---|---|
| Moins de 100 000 lignes, à ouvrir dans Excel | CSV UTF-8 |
| Flux ajouté en continu, structure variable | NDJSON |
| Plusieurs millions de lignes, analyse | Parquet, lu avec pyarrow ou DuckDB |
| Plusieurs tables reliées, mises à jour, un seul écrivain | SQLite |
| Plusieurs écrivains ou accès serveur | PostgreSQL, si disponible |

## Règles

1. `raw/` est intouchable : on peut toujours rejouer le nettoyage sans recollecter.
2. Chaque ligne contient `source_url` et `scraped_at`.
3. Déduplique sur une clé métier stable (SKU, identifiant), sinon sur un hash des champs.
4. En base : clé primaire, types corrects, index sur les colonnes de recherche, insertion par lots dans une transaction.
5. Au-delà de 1 Go, partitionne : `exports/annee=2026/mois=11/`.
6. Consigne à la fin : lignes collectées, valides, rejetées, doublons retirés, taille.

Si Windows bloque le chargement d'une bibliothèque (« stratégie de contrôle d'application », fréquent pour pandas et DuckDB), n'essaie pas de désactiver cette protection : utilise pyarrow, SQLite ou le module csv de Python.
