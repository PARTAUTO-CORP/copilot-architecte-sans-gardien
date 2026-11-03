---
name: crawlbase
description: Utilisation du serveur MCP Crawlbase — pages JavaScript ou protégées, rendu Markdown et captures d'écran, avec proxies et anti-bot gérés.
---

# Crawlbase

**Serveur :** `crawlbase` (MCP distant, jeton à fournir via `mcp-scraping.ps1`). Il offre jusqu'à 5 000 requêtes gratuites.

| Besoin | Outil |
|---|---|
| HTML d'une page | `crawl` |
| Texte propre pour analyse | `crawl_markdown` |
| Capture d'écran pour contrôle visuel | `crawl_screenshot` |

**Bonnes pratiques :**
- Le rendu, les proxies et l'anti-bot s'appliquent à chaque appel : utilise-le quand une requête directe échoue, pas pour chaque page.
- Utilise une capture d'écran pour diagnostiquer une page qui renvoie un contenu inattendu.
- Ce classement vient de Crawlbase lui-même ; compare sur ta cible avec les autres services avant un gros volume.
