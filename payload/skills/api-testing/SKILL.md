---
name: api-testing
description: Conception et exécution de tests d'API — cas nominal, authentification, autorisations, validation, erreurs, limites et schémas.
---

# Tests d'API

Pour chaque endpoint, couvre :

1. **Nominal :** statut, schéma et contenu.
2. **Authentification :** absente, expirée, invalide.
3. **Autorisation :** rôle insuffisant, accès à la ressource d'un autre utilisateur.
4. **Validation :** champs manquants, mauvais types, bornes, chaînes longues.
5. **Erreurs :** 404, conflit, format d'erreur, absence de fuite interne.
6. **Effets :** ce qui est réellement persisté, idempotence.

En cas d'échec, compare requête et réponse complètes aux attentes et indique si le défaut vient de l'API, du test ou des données.
