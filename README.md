# Copilot Architecte (sans Gardien)

Une équipe de 12 agents pour GitHub Copilot CLI, sous Windows. Elle travaille en autonomie, ne pose de question que pour proposer un autre niveau d'effort, décide avec JEV et un second modèle, scrape à grande échelle, et pentest tes propres applications. Cette version n'a pas de Gardien : aucune commande n'est contrôlée avant de s'exécuter.

| Ce que tu cherches | Où aller |
|---|---|
| Installer avec une IA, en une phrase | [Juste en dessous](#installer-avec-une-ia) |
| Installer sans IA, ou tout comprendre | [INSTALL_MANUEL.md](INSTALL_MANUEL.md) |
| Présentation complète | [docs/GUIDE_COPILOT_ARCHITECTE.pdf](docs/GUIDE_COPILOT_ARCHITECTE.pdf) |
| Tous les réglages et les limites | [docs/REFERENCE_TECHNIQUE.md](docs/REFERENCE_TECHNIQUE.md) |

## Ce que ça fait

Tu parles à un agent coordinateur, l'Architect. Il planifie, confie chaque partie au bon spécialiste, contrôle le résultat et te rend un rapport.

| Partie | Ce qu'elle apporte |
|---|---|
| 12 agents | Architect, frontend, backend, base de données, DevOps, sécurité, scraping, pentest, stratégie de test, tests automatisés, revue de code, documentation |
| 28 skills | Les méthodes que les agents chargent à la demande |
| Copilot débridé | Plus aucune demande d'autorisation, ni bac à sable, ni limite de relances |
| Scraping | Un moteur local pour les gros volumes, et des serveurs MCP pour les sites protégés ou très JavaScript |
| Aide à la décision | JEV pour les choix rapides, un second modèle pour les choix lourds, Jev Ultrafast dans le navigateur |
| Installation et contrôle | Chaque installation peut être relancée, sauvegarde tes fichiers modifiés et se contrôle avec `verifier.ps1` |

Le détail fichier par fichier est dans [INSTALL_MANUEL.md](INSTALL_MANUEL.md#ce-que-linstallation-change-sur-ton-pc).

## Installer avec une IA

N'importe quelle IA capable d'agir sur ton PC convient : Copilot CLI, Claude Code, Codex, Cursor…

**1. Lance-la en mode sans restriction,** sinon elle te demandera une validation à chaque commande :

| IA | Commande |
|---|---|
| GitHub Copilot CLI | `copilot --yolo` |
| Claude Code | `claude --dangerously-skip-permissions` |
| Codex CLI | `codex --yolo` |
| Cursor CLI | `cursor-agent --force` |

Ces options changent parfois de nom. Pour une autre IA, cherche son mode « auto-approve » ou « full access ».

**2. Donne-lui l'un de ces textes.**

Si le dossier est déjà sur ta machine, lance l'IA depuis ce dossier et écris :

```text
Installe.
```

Si le dossier n'est pas sur ta machine, remplace `TON-COMPTE` et colle :

```text
Installe Copilot Architecte sur ce PC, en toute autonomie et jusqu'au bout.
Clone https://github.com/TON-COMPTE/copilot-architecte dans mon dossier personnel, ou télécharge son ZIP si Git est absent.
Place-toi dans ce dossier, lis AGENTS.md et applique-le étape par étape.
Si ta session demande des autorisations, demande-moi une seule fois de te relancer en mode sans restriction.
Ne me demande jamais une clé dans la conversation.
```

L'IA installe, contrôle, puis te rend un rapport avec ce qu'il te reste à faire. La procédure qu'elle suit est dans [AGENTS.md](AGENTS.md).

## Installer d'un double-clic

Double-clique sur `installer.cmd`. Il installe ce qui manque, te demande de choisir entre mise à jour et réinitialisation (Entrée pour la mise à jour), ouvre une fenêtre pour tes clés, puis lance le contrôle. Windows peut demander une autorisation pour Node.js et Python, et SmartScreen peut afficher un avertissement sur un fichier téléchargé.

Pour installer sans IA ni double-clic, étape par étape, suis [INSTALL_MANUEL.md](INSTALL_MANUEL.md).

## Ensuite

Ouvre un nouveau terminal PowerShell 7 :

| Commande | Effet |
|---|---|
| `cop` | Session avec l'Architect, sans aucune confirmation |
| `copr "ta demande"` | Travaille jusqu'au bout sans interface, puis s'arrête |
| `cop-pentest` | Session pour attaquer et auditer tes propres applications |

Ajoute tes clés de service quand tu veux avec `.\mcp-scraping.ps1`. Sans elles, les agents utilisent les outils gratuits.

## À lire avant d'installer

**`cop` donne à Copilot tous les droits de ton compte Windows, sans rien te demander.** Il peut supprimer des fichiers, utiliser tes identifiants et envoyer des données sur le réseau. Aucun Gardien ne contrôle ses commandes : une page piégée ou un dépôt hostile peut lui faire exécuter n'importe quoi. Installe le kit sur ton propre poste, garde des sauvegardes et la protection en temps réel de Windows, et évite une machine avec des accès de production ou des données de tiers.

Les services externes (TypeSafe, Firecrawl, etc.) et les crédits Copilot sont payants selon leur usage : aucun plafond n'est posé. N'attaque que les applications dont tu as la responsabilité.

## Prérequis

- Windows 10 ou 11.
- Un abonnement GitHub Copilot.
- Tout le reste s'installe seul : PowerShell 7.3+, Python 3.12+, Node 24+ et Copilot CLI. Il faut `winget` si l'un des trois premiers manque.
- Facultatif : Git pour cloner le dépôt, Google Chrome pour le navigateur Jev.

## Mettre à jour

Récupère la nouvelle version du dossier, puis relance `installer.cmd`. Tes réglages et tes fichiers personnels restent en place.

## Désinstaller

Suis la section « Retour arrière » de la [référence technique](docs/REFERENCE_TECHNIQUE.md). Chaque fichier modifié est sauvegardé dans `~/.copilot/backups/`.
