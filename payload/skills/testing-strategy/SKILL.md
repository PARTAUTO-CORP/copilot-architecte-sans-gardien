---
name: testing-strategy
description: Conception d'une stratégie de test — niveaux, priorisation par les risques, smoke, régression et couverture utile.
---

# Stratégie de test

1. Liste ce qui coûterait le plus cher en cas de panne : argent, données, sécurité, parcours principal.
2. Pour chaque risque, choisis le niveau le plus bas qui le détecte vraiment.
3. Garde beaucoup de tests unitaires, assez d'intégration et quelques parcours de bout en bout.
4. Définis un smoke rapide et une régression complète, et ce qui bloque une livraison.
5. Vise les comportements critiques plutôt qu'un pourcentage de couverture.
6. Ajoute un test de non-régression à chaque défaut corrigé.
