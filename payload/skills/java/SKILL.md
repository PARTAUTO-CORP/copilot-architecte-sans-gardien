---
name: java
description: Développement Java — typage, collections, streams, exceptions, concurrence et tests.
---

# Java

1. Repère la version du JDK et l'outil de build du projet, et utilise les fonctionnalités disponibles (records, `sealed`, pattern matching).
2. Préfère l'immuabilité ; expose les types les plus généraux utiles.
3. Utilise les streams quand ils clarifient le code, sinon une boucle.
4. Lève des exceptions précises avec du contexte ; ne les avale jamais.
5. En concurrence, passe par `java.util.concurrent` plutôt que par des threads manuels.
6. Vérifie avec `mvn verify` ou `gradle check`.
