---
name: docker
description: Conteneurisation — images reproductibles, multi-stage, Compose, réseaux, volumes, health checks et sécurité.
---

# Docker

1. Fixe les versions des images de base ; utilise des builds multi-stage pour réduire l'image finale.
2. Ordonne les couches pour profiter du cache et maintiens un `.dockerignore`.
3. Exécute le processus avec un utilisateur non root quand l'application le permet.
4. Ne mets aucun secret dans l'image : passe-les à l'exécution.
5. Ajoute des health checks et des volumes nommés pour les données.
6. Vérifie en construisant et en lançant réellement, puis lis les logs.
