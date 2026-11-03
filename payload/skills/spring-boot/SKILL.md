---
name: spring-boot
description: Backend Spring Boot — REST, Spring Security, JPA/Hibernate, transactions, validation, gestion d'erreurs et tests d'intégration.
---

# Spring Boot

1. Repère la version de Boot et suis sa documentation (`jakarta.*` à partir de la 3).
2. Injecte par constructeur et garde les contrôleurs minces.
3. Valide avec `@Valid` et centralise les erreurs dans un `@RestControllerAdvice`.
4. Expose des DTO et non des entités. Traque le chargement paresseux et les N+1.
5. Place `@Transactional` sur les services et n'y fais pas d'appels réseau longs.
6. Configure Spring Security explicitement et teste les refus d'accès.
7. Écris des tests d'intégration, avec Testcontainers si Docker est disponible.
