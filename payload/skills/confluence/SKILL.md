---
name: confluence
description: Lecture et mise à jour de pages Confluence — espaces, exigences, décisions, procédures, et détection de dérive documentaire.
---

# Confluence

1. Une skill ne crée pas de connexion : vérifie d'abord l'accès réel (MCP configuré, API avec jeton, navigateur).
2. Si aucun accès n'existe, configure-le quand les identifiants sont disponibles, sinon déclare `BLOCKED` et précise ce qui manque.
3. Conserve l'URL, l'identifiant et la date de mise à jour de chaque page utilisée.
4. Compare la page au code : un écart est un `CONFLICT` à signaler, pas une vérité à choisir.
5. Lors d'une modification, relis la page après écriture pour confirmer le résultat.
