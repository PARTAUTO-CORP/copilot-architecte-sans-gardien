---
name: security
description: Développement sécurisé — authentification, autorisation, sessions, JWT, OAuth, OWASP, secrets, XSS, CSRF, SSRF, injection SQL, CORS et validation.
---

# Sécurité applicative

Vérifie en priorité :

1. **Autorisation :** contrôle côté serveur à chaque accès, y compris aux ressources d'autres utilisateurs.
2. **Authentification et sessions :** expiration, révocation, cookies `HttpOnly`/`Secure`/`SameSite`, validation complète des JWT, `state` et PKCE en OAuth.
3. **Entrées :** requêtes paramétrées, échappement en sortie, CSRF, SSRF, téléversements, traversée de chemins.
4. **Secrets :** absents du code et de l'historique Git, rotation si exposés.
5. **Configuration :** CORS précis, en-têtes de sécurité, erreurs sans détails internes.
6. **Dépendances :** lance l'audit de l'écosystème (`npm audit`, `pip-audit`, OWASP Dependency-Check).

Rapporte la gravité, le scénario d'exploitation, la preuve et la correction.
