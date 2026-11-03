---
name: gitlab-ci
description: Pipelines GitLab CI/CD — stages, jobs, rules, needs, variables, runners, artefacts, rapports et diagnostic d'échecs.
---

# GitLab CI

1. Lis `.gitlab-ci.yml` et ses `include` avant de changer quoi que ce soit.
2. Exprime les conditions avec `rules` et les dépendances avec `needs`.
3. Mets en cache les dépendances et publie les rapports de tests en artefacts.
4. Conserve les secrets dans des variables masquées et protégées.
5. Pour diagnostiquer, lis le log complet du job et distingue le code, le test, le runner et la configuration.
6. Valide le YAML avec le lint de l'API GitLab lorsqu'il est accessible, puis lance le pipeline.
