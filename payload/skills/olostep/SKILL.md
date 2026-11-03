---
name: olostep
description: Utilisation du serveur MCP Olostep — scraping, recherche, cartes de sites, crawls et lots allant jusqu'à 100 000 URL.
---

# Olostep

**Serveur :** `olostep` (MCP distant, connexion par `/mcp` ou clé API). La clé se crée sur olostep.com/dashboard/api-keys.

| Besoin | Outil |
|---|---|
| Une page | `scrape_website` ou `get_webpage_content` |
| Recherche web | `search_web` |
| Réponse sourcée | `answers` |
| Lister les URL d'un site | `create_map`, `get_website_urls` |
| Parcourir un site | `create_crawl`, `get_crawl_results` |
| Liste d'URL connue | `batch_scrape_urls`, `get_batch_results` |

**Bonnes pratiques :**
- Le lot est sa grande force : de 2 à 100 000 URL de manière asynchrone, à 1 crédit l'URL. Les nouveaux comptes sont limités à 100 URL par lot jusqu'à une demande à Olostep ; découpe en conséquence.
- Les résultats se lisent par pages de 100 éléments au maximum (`items_limit`, 20 par défaut) : parcours toutes les pages, puis vérifie le total.
- Écris les résultats sur le disque au fil de l'eau, au lieu de les garder dans la conversation.
- Des skills officielles existent sur `olostep.com/skills/<nom>/SKILL.md` si tu as besoin de plus de détails.
