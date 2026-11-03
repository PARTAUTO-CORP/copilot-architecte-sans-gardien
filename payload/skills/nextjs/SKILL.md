---
name: nextjs
description: Applications Next.js, React et TypeScript — App Router, Server Components, Server Actions, rendu, performances, SEO et sécurité.
---

# Next.js

1. Repère la version et le routeur utilisés, puis consulte la documentation de cette version en cas de doute.
2. Reste en Server Components par défaut ; ajoute `"use client"` au plus bas de l'arbre.
3. Choisis le rendu et le cache explicitement selon la fraîcheur requise.
4. Valide les entrées et contrôle les droits dans chaque Server Action et route API.
5. Ne fais jamais passer de secret par une variable `NEXT_PUBLIC_`.
6. Utilise `next/image`, `next/font` et l'API `metadata`.
7. Vérifie avec `next build`, le lint et un parcours réel dans le navigateur.
