---
name: database
description: SQL et persistance — schémas, relations, migrations, index, transactions et optimisation de requêtes.
---

# Base de données

1. Lis le schéma réel, pas seulement les entités de l'ORM.
2. Pose les contraintes en base : clés, `NOT NULL`, unicité, clés étrangères.
3. Rends les migrations incrémentales et compatibles avec le code en cours de déploiement.
4. Crée les index à partir des requêtes réelles et contrôle avec `EXPLAIN`.
5. Garde les transactions courtes et choisis l'isolation selon le besoin.
6. Traque les N+1 et les requêtes sans limite. Utilise toujours des requêtes paramétrées.
7. Pour une grosse table, procède par lots et anticipe les verrous.
