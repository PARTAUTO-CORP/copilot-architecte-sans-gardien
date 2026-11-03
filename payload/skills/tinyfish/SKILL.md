---
name: tinyfish
description: Utilisation du serveur MCP TinyFish — agents web pilotés par objectif, navigateurs distants, recherche, récupération de contenu, datasets et surveillance de pages.
---

# TinyFish

**Serveur :** `tinyfish` (MCP distant, connexion OAuth par `/mcp` dans Copilot).

| Besoin | Outil |
|---|---|
| Recherche web, gratuite dans une limite quotidienne | `search` |
| Contenu de pages, 10 URL maximum par appel | `fetch_content` |
| Parcours complexe décrit par un objectif | `run_web_automation` |
| Plusieurs parcours en parallèle | `run_web_automation_async`, `get_run`, `batch_status` (8 identifiants maximum) |
| Recherche approfondie | `start_deep_research`, `get_deep_research` |
| Constituer un jeu de données | `plan_dataset`, `create_dataset`, `populate_dataset`, `get_dataset_rows` |
| Surveiller une page | `create_monitor`, `run_monitor`, `get_monitor` |
| Navigateur distant | `create_browser_session`, `close_browser_session` |

**Bonnes pratiques :**
- Commence par `fetch_content`, gratuit : l'automatisation est facturée à l'étape (0,016 $) et le navigateur à la minute.
- Donne des objectifs précis : champs voulus, format de sortie, condition d'arrêt.
- Ferme les sessions de navigateur et annule les exécutions devenues inutiles.
- N'appelle jamais `top_up_wallet` sans demande explicite de l'utilisateur : cet outil dépense son argent. Contrôle le solde avec `get_wallet`.
