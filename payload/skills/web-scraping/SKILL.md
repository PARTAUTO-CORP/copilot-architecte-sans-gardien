---
name: web-scraping
description: Méthode de scraping à toute échelle — choix de l'outil, extraction précise, gros volumes, reprise, sites JavaScript ou protégés, contrôle qualité. À utiliser pour toute collecte de données web.
---

# Scraping web

## Choisir l'outil

Prends le premier niveau qui fonctionne : il est aussi le plus rapide et le moins cher.

| Niveau | Quand | Outil |
|---|---|---|
| 1. Source directe | API, sitemap, flux, JSON embarqué | HTTP simple ou `scrape_engine.py` |
| 2. Volume, HTML statique | Liste d'URL, de 100 à plusieurs millions de pages | `scrape_engine.py` |
| 3. Projet complexe | Beaucoup de règles de parcours | Scrapy, dans le venv du kit |
| 4. Site JavaScript, pages peu nombreuses | Contenu chargé par script | MCP `firecrawl` ou `crawlbase` |
| 5. Parcours interactif | Clics, formulaires, connexion à ton propre compte | MCP `playwright` ou `tinyfish` |
| 6. Gros lot géré | Grand volume sans infrastructure locale | MCP `olostep` (batch) |
| 7. Site qui bloque | Blocages répétés aux niveaux précédents | MCP `decodo`, `oxylabs`, `scrapingbee`, `brightdata`, `crawlbase` |
| Scrapers prêts à l'emploi | Google Maps, réseaux sociaux, places de marché | MCP `apify` |
| Lecture d'une page publique | Article, documentation | MCP `jina` |

Test Proxyway (octobre 2026, cibles difficiles comme Google et Amazon) : Decodo 87 % de réussite en 15 s, Oxylabs 86 % en 17 s, ScrapingBee 84 % en 25 s, Firecrawl 34 % en 8 s. Ces chiffres vieillissent : teste sur ta cible avant d'engager un gros volume.

Vérifie la disponibilité réelle d'un serveur avec un appel d'essai. S'il manque, passe au suivant et signale-le.

## Moteur local

Le moteur se trouve dans `~/.copilot/scraper/`. Utilise le Python de `~/.copilot/scraper/venv` :

```powershell
python scrape_engine.py crawl <projet> --urls urls.txt --selectors selecteurs.json --concurrency 100 --per-host 4 --delay 0.25
python scrape_engine.py status <projet>
python scrape_engine.py export <projet> --format parquet
```

- La file d'URL vit en SQLite : après un arrêt, relance la même commande et le travail reprend.
- Sélecteurs : `{"titre":"h1","prix":".price","images[]":"img@src"}`.
- `--depth 2 --follow "/produits/"` suit les liens qui correspondent.
- La vitesse se règle par `--per-host` et `--delay`. En cas de 429 ou de blocage, réduis-les : forcer provoque un bannissement et perd plus de temps.

## Extraire avec précision

1. Cherche les données structurées avant le CSS : JSON-LD, `__NEXT_DATA__`, appels XHR, microdonnées.
2. Préfère les sélecteurs stables : attributs `data-*`, `itemprop`, identifiants. Évite les classes générées et les chemins par position.
3. Normalise : prix en nombre avec devise, dates en ISO 8601, texte sans espaces parasites.
4. Valide chaque ligne avec un schéma ; rejette vers `rejects/` ce qui échoue, sans le perdre.
5. Pour le texte d'article, utilise `trafilatura`.

## Détecter les faux succès

Un HTTP 200 peut cacher un captcha, une page « accès refusé », une connexion demandée ou un gabarit modifié. Contrôle les champs obligatoires et une taille de page plausible. Si le taux d'échec dépasse 5 % sur un lot, arrête-toi et cherche la cause avant de consommer davantage.

## Cadre légal

- Respecte `robots.txt` et les limites des sites par défaut ; le moteur le fait. N'utilise `--ignore-robots` qu'avec une raison que tu notes dans le rapport.
- Ne force ni identifiant, ni contrôle d'accès, ni paywall : n'accède qu'à ce qui est public ou à ce que l'utilisateur a le droit de consulter.
- Les données personnelles relèvent du RGPD : ne collecte que le nécessaire et signale leur présence à l'utilisateur.
- Si les conditions d'un site posent problème pour l'usage prévu, signale-le dans le rapport.
