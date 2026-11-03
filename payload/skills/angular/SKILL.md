---
name: angular
description: Bonnes pratiques Angular — composants standalone, signaux, RxJS, formulaires réactifs, routing, HTTP et tests. À utiliser pour tout code Angular.
---

# Angular

1. Repère la version dans `package.json` et suis les conventions déjà présentes dans le projet.
2. Préfère les composants standalone et `ChangeDetectionStrategy.OnPush`, si la version le permet.
3. Mets l'état local dans des signaux et les flux asynchrones dans RxJS ; évite les `subscribe` imbriqués et libère les abonnements (`async` pipe, `takeUntilDestroyed`).
4. Place l'accès HTTP dans des services et la logique transverse dans des intercepteurs.
5. Utilise des formulaires réactifs typés et affiche les erreurs de validation.
6. Charge les routes en différé et protège-les avec des guards ; rappelle que le contrôle réel se fait côté serveur.
7. Vérifie avec `ng build` et `ng test`.
