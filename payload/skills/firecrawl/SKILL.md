---
name: firecrawl
description: Utilisation du serveur MCP Firecrawl — scrape, map, crawl, recherche, parsing de fichiers et agent, sortie Markdown ou JSON structuré.
---

# Firecrawl

**Serveur :** `firecrawl` (MCP distant). Connexion par `/mcp` dans Copilot. Sans compte, seuls `firecrawl_search`, `firecrawl_scrape` et `firecrawl_parse` sont disponibles, avec une limite quotidienne.

| Besoin | Outil |
|---|---|
| Une page en Markdown ou JSON | `firecrawl_scrape` |
| Lister toutes les URL d'un site | `firecrawl_map` |
| Parcourir un site entier | `firecrawl_crawl`, puis `firecrawl_check_crawl_status` |
| Recherche web avec contenu | `firecrawl_search` |
| PDF et documents | `firecrawl_parse` |
| Cliquer ou remplir sur une page | `firecrawl_interact`, puis `firecrawl_interact_stop` |
| Tâche autonome sur plusieurs sites | `firecrawl_agent`, puis `firecrawl_agent_status` |

**Bonnes pratiques :**
- Pour extraire des champs, utilise `firecrawl_scrape` en format JSON avec un schéma : l'ancien outil Extract n'existe plus.
- Lance `firecrawl_map` avant un crawl et filtre les URL, pour ne pas payer des pages inutiles.
- Le serveur n'a pas d'outil de lot : pour une longue liste d'URL, préfère `olostep` ou le moteur local.
- Sur les sites très protégés, Firecrawl réussit moins souvent : passe au niveau 7 de `web-scraping` après des échecs répétés.
