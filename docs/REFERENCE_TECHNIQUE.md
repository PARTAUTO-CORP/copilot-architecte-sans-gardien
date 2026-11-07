# KIT COPILOT ARCHITECTE — MODE PLEINE PUISSANCE

**Version du kit :** 2.2 sans Gardien (3 novembre 2026)
**Vérifié avec :** GitHub Copilot CLI 1.0.105, Windows 11, PowerShell 7.6, Python 3.12, Node 24
**Prérequis :** un abonnement GitHub Copilot. `installer.cmd` installe le reste : Copilot CLI, PowerShell 7.3 ou plus récent, Python 3.12+ pour le moteur de scraping et le navigateur Jev, Node 24+ pour les serveurs locaux.

Les noms de réglages changent d'une version à l'autre. Sur une version plus récente, compare d'abord avec `copilot help config` et `copilot help permissions`.

Ce document est la référence technique. Pour installer : `README.md` et `INSTALL_MANUEL.md`. Présentation : `docs/GUIDE_COPILOT_ARCHITECTE.pdf`.

## 1. Ce que contient le kit

| Élément | Rôle |
|---|---|
| `payload/agents/` | Les 12 agents, fichiers réels à installer |
| `payload/skills/` | Les 28 skills, fichiers réels à installer |
| `payload/copilot-instructions.md` | Les règles communes : autonomie, preuve, statuts, contrats, répartition |
| `payload/scraper/` | Le moteur de scraping en masse et ses dépendances Python |
| `payload/decision/` | Le serveur MCP de décision vers TypeSafe et le navigateur Jev Ultrafast, à version figée |
| `installer.cmd`, `bootstrap.ps1` | Installent les prérequis manquants, lancent `install.ps1`, puis `verifier.ps1` |
| `installer.sh` | L'équivalent Linux de `installer.cmd`. Partie système (root ou `sudo`) : Google Chrome, ICU, module `venv`. Partie compte : PowerShell 7, Node 24, Copilot CLI et au besoin un Python 3.12 autonome (uv) dans `~/.local`, puis `bootstrap.ps1`. `-SystemOnly` ne fait que la partie système |
| `AGENTS.md` | La procédure suivie par une IA qui installe le kit |
| `install.ps1` | Installe le tout et débride Copilot |
| `mcp-scraping.ps1` | Déclare les serveurs MCP de scraping et de décision, et demande les clés |
| `verifier.ps1` | Contrôle l'installation et affiche la matrice Agent → Skills |
| `tests/` | Tests du moteur, du serveur Jev et du navigateur Jev |

`payload/` est la seule liste de référence : pour ajouter un agent ou une skill, dépose le fichier et relance `install.ps1`.

`install.ps1` crée aussi deux fichiers absents de `payload/` : `~/.copilot/statusline.ps1`, la ligne d'état, et `~/.copilot/architecte-manifest.json`, la liste des fichiers appartenant au kit.

## 2. Installation

```powershell
.\installer.cmd
# ouvrir un nouveau terminal PowerShell 7
cop
```

Sous Linux, `bash installer.sh`, puis `pwsh` dans un nouveau terminal, puis `cop`. Les scripts PowerShell sont les mêmes ; seules différences : les environnements Python sont dans `venv/bin/python` au lieu de `venv\Scripts\python.exe`, le profil est `~/.config/powershell/profile.ps1`, le fichier MCP de VS Code `~/.config/Code/User/mcp.json`, les clés se tapent dans le même terminal au lieu d'une fenêtre séparée, la page TypeSafe ne s'ouvre que s'il y a un bureau graphique (`DISPLAY` ou `WAYLAND_DISPLAY`), et `~/.copilot` est réservé à son propriétaire (`chmod 700`) car il contient les clés en clair. Les contrôles Windows Defender sont ignorés ; `verifier.ps1` signale à la place l'absence de Chrome et une installation pour root. Pour un VPS, voir « Installer sur un VPS » dans le README.

L'installation demande d'abord le mode : mise à jour, ou réinitialisation. Elle ouvre ensuite une fenêtre PowerShell 7 pour les clés des services : colle-les dans les champs masqués ou appuie sur Entrée pour passer. Tu pourras les ajouter plus tard avec `.\mcp-scraping.ps1`. Ne donne jamais une clé à une IA dans une conversation.

| Mode | Effet |
|---|---|
| Mise à jour (par défaut) | Ajoute et met à jour les fichiers du kit, après sauvegarde. Garde tes réglages et tes fichiers |
| Réinitialisation (`-Reset`) | Fait la même chose, et retire aussi les anciens fichiers listés dans le manifeste du kit, après sauvegarde. Un fichier absent du manifeste n'est jamais retiré |

| Commande | Effet |
|---|---|
| `cop` | Session interactive, Architect en coordinateur, tous les verrous levés |
| `cop -i "ta demande"` | Pareil, en lançant directement la demande |
| `copr "ta demande"` | Sans interface : travaille jusqu'au bout, puis s'arrête |
| `copr "ta demande" --fleet` | Pareil, avec des sous-agents en parallèle |
| `cop-pentest` | Session avec l'agent Pentest (section 5 ter) |

Options de `install.ps1` : `-Model <nom>` fixe un modèle disponible sur ton abonnement, `-Effort <niveau>` règle son effort (`high` par défaut ; le mode Auto choisit lui-même), `-NoPrompt` saute le choix du mode et les questions sur les clés (le mode est alors la mise à jour), `-Reset` réinitialise, sans confirmation s'il est combiné à `-NoPrompt`, `-SkipScraperDeps` saute le téléchargement des paquets Python. Pour essayer sans toucher à ton installation : `-CopilotHome <dossier> -ProfilePath <fichier> -SkipUserEnv -VsCodeMcp ''`. `verifier.ps1` accepte les trois premières.

## 3. Ce qui est débridé

| Réglage | Où | Effet |
|---|---|---|
| `defaultPermissionMode: allow-all` | `settings.json` | Plus aucune demande d'autorisation au démarrage d'une session interactive |
| `COPILOT_ALLOW_ALL=true` | `cop`, `copr` | Outils approuvés et dossier courant accepté sans question, le temps de la session |
| `--yolo` | `cop`, `copr` | Tous les outils, tous les chemins, toutes les URL |
| `defaultMode: interactive` | `settings.json` | `cop` et `cop-pentest` s'ouvrent en mode interactif |
| `--autopilot` | `copr` | Continue seul jusqu'à la fin de la tâche |
| `askUser: true` | `settings.json` | L'agent peut demander s'il faut changer le niveau d'effort |
| `--no-ask-user` | `copr` | Ne pose aucune question : l'agent décide et note ses hypothèses |
| `stayInAutopilot: false` | `settings.json` | Après `/autopilot`, revient au mode interactif à la fin de la tâche |
| `--max-autopilot-continues 999999` | `copr` | Enlève en pratique la limite de relances (l'aide indique 5 par défaut, la doc « illimité ») |
| `--enable-all-github-mcp-tools` | `cop`, `copr` | Tous les outils GitHub MCP au lieu du sous-ensemble par défaut |
| `--allow-all-mcp-server-instructions` | `cop`, `copr` | Charge les instructions de tous les serveurs MCP |
| `--reasoning-effort high` | `cop`, `copr`, `cop-pentest` | Effort par défaut, seulement avec un modèle fixé : le mode Auto refuse cette option |
| `experimental: true` | `settings.json` | Fonctions expérimentales actives |
| `sandbox.enabled: false` | `settings.json` | Aucun bac à sable sur les commandes |
| `deniedUrls: []`, retrait de `disableBypassPermissionsMode` | `settings.json` | Retire les interdictions du fichier utilisateur, qui l'emporteraient sur `--yolo` |
| `powershellFlags` avec `-ExecutionPolicy Bypass` | `settings.json` | Les scripts PowerShell ne sont plus bloqués |
| `continueOnAutoMode: true` | `settings.json` | Passe sur Auto en cas de limite de débit au lieu de s'arrêter |
| `keepAlive: busy` | `settings.json` | Le PC ne se met pas en veille pendant le travail |
| `memory: true`, `--enable-memory` | Les deux | Mémoire entre les sessions |
| `subagents.agents.rubber-duck.autoInvoke: true` | `settings.json` | Copilot consulte seul le critique d'une autre famille de modèles aux moments importants |
| `tools: ["*"]` | Chaque agent | Tous les outils pour tous les agents, y compris code-review |
| `statusLine`, `statusline.ps1` | `settings.json` | Affiche modèle, dossier, branche, contexte, requêtes et durée, actualisés toutes les 5 secondes |
| `footer.showQuota`, `footer.showContext` | `settings.json` | Affiche le quota et le contexte en bas de la session |

Aucune limite de crédits IA n'est posée. Aucune limite n'est posée non plus à l'autonomie (section 4).

### Ce que cela implique

**Copilot agit avec tous les droits de ton compte Windows, sans rien te demander.** Il peut supprimer des fichiers, utiliser tes identifiants et envoyer des données sur le réseau. Aucun Gardien ne contrôle ses commandes. Trois conséquences concrètes :

1. **Contenus piégés :** une page scrappée, une issue ou un fichier peut contenir des consignes malveillantes. Les règles communes demandent de les ignorer, mais ce n'est pas une garantie technique.
2. **Dépôts inconnus :** `cop` fait confiance au dossier sans vérifier sa configuration Copilot. Inspecte un dépôt inconnu avant d'y travailler.
3. **Crédits et services payants :** un effort élevé, l'autopilot sans limite de `copr`, les sous-agents, le rubber duck, JEV et les API de scraping consomment vite. `/usage` montre la consommation de Copilot ; chaque service de scraping a son propre tableau de bord.

Installe ce kit seulement sur ton poste, ou sur celui d'une personne qui a lu cette section. Évite une machine contenant des accès de production ou des données de tiers.

## 4. Sans Gardien : ce qui n'est plus protégé

Cette version n'installe ni le Gardien, ni son hook, ni le contrôle du dossier au lancement, ni la skill `script-guard`. `install.ps1` retire ceux d'une installation précédente, après les avoir sauvegardés dans `~/.copilot/backups/`.

- **Commandes :** plus rien ne refuse une commande ou un script hostile. Seuls l'antivirus et les droits de ton compte Windows limitent les dégâts. Garde la protection en temps réel de Windows activée ; `install.ps1` et `verifier.ps1` signalent si elle est coupée.
- **Dépôts :** `cop` fait confiance au dossier courant sans le vérifier. Les hooks et les serveurs MCP d'un dépôt se chargent donc sans question : inspecte un dépôt inconnu avant d'y lancer `cop`.
- **Secrets :** rien ne bloque l'envoi d'un secret vers JEV. Seule la consigne donnée aux agents l'interdit.
- **Scripts reçus :** `garde.ps1 -Scan` n'existe plus. Analyse un fichier douteux avec Windows Defender ou lis-le toi-même.

## 5. L'agent Scraper

Il couvre la collecte de bout en bout : reconnaissance, prototype, production, contrôle, livraison. Ses skills : `web-scraping`, `data-organization`, `firecrawl`, `tinyfish`, `olostep`, `crawlbase`, `file-intelligence`, `source-access`, `database`.

Il choisit toujours l'outil le moins coûteux qui fonctionne.

### Moteur local

`~/.copilot/scraper/scrape_engine.py` gère les gros volumes sans frais d'API : file d'URL en SQLite avec reprise après arrêt, limites par site, respect de `robots.txt`, nouvelles tentatives sur les erreurs temporaires, dédoublonnage du contenu brut, extraction par sélecteurs CSS, exports NDJSON, CSV et Parquet. Mesuré à environ 100 pages par seconde contre un serveur local ; sur le vrai web, le débit dépend surtout des limites de chaque site.

Il obtient du HTML : les sites protégés ou très JavaScript passent par les serveurs MCP.

### Serveurs MCP

| Serveur | Accès | Point fort |
|---|---|---|
| `firecrawl` | Connexion par `/mcp` | Crawl et carte de sites, Markdown et JSON |
| `tinyfish` | Connexion par `/mcp` | Agents pilotés par objectif, datasets, surveillance |
| `olostep` | Connexion par `/mcp` ou clé | Lots jusqu'à 100 000 URL |
| `apify` | Connexion par `/mcp` | Scrapers prêts pour des sites précis |
| `jina` | Sans clé pour une partie des outils | Lecture de pages publiques |
| `playwright` | Local, sans compte | Parcours interactifs dans un navigateur |
| `crawlbase` | Clé | Pages JavaScript ou protégées |
| `decodo` | Clé | 1er au test Proxyway : 87 % de réussite |
| `oxylabs` | Clé | 2e au test Proxyway : 86 % |
| `scrapingbee` | Clé | 3e au test Proxyway : 84 % |
| `brightdata` | Clé | Le plus large, environ 70 outils |

Sources : [Proxyway](https://proxyway.com/best/mcp-servers-for-web-scraping) et [Crawlbase](https://crawlbase.com/blog/best-mcp-servers-for-web-scraping/). Proxyway ne classe pas TinyFish, Olostep ni Crawlbase, et le classement de Crawlbase vient de Crawlbase lui-même. ScraperAPI, listé par Crawlbase, n'est pas inclus, car son accès hébergé n'a pas pu être vérifié.

Les serveurs à clé ne sont déclarés que si tu fournis une clé. La plupart demandent un compte et certains sont payants. Le format documenté par Copilot stocke les clés en clair dans `~/.copilot/mcp-config.json` : ne partage pas ce fichier.

### Rangement

Chaque projet a son dossier `scraping/<date>_<sujet>/` : `README.md`, `config/`, `state.db`, `raw/`, `clean/`, `rejects/`, `exports/`, `scripts/`, `manifest.json`. Le format dépend du volume : CSV, NDJSON, Parquet, SQLite ou PostgreSQL. Détails dans la skill `data-organization`.

### Sur Windows avec le contrôle intelligent des applications

Cette protection peut bloquer `pandas` et `duckdb` (constaté sur le poste de test). Le moteur n'en dépend pas : il utilise `pyarrow`. Laisse cette protection active.

## 5 bis. Décisions

Quand un agent hésite, il applique la skill `decision-support`. La seule question permise à l'utilisateur porte sur le niveau d'effort. Tous les agents y ont accès.

| Situation | Outil | Coût |
|---|---|---|
| Fait, calcul, date | Du code. L'éditeur de Jev déconseille le modèle pour cela | Gratuit |
| Choix rapide entre plusieurs options, classement, routage | JEV, par appel direct à TypeSafe | 0,042 $ par million de jetons en entrée |
| Décision lourde, échecs répétés | Rubber duck, le critique intégré à Copilot | Crédits Copilot |
| Problème flou, autres outils indisponibles | `sequential-thinking`, MCP local | Gratuit |
| Objectif dans un navigateur | Jev Ultrafast (`jev-browser`), ou `playwright` sans clé | Clé TypeSafe (et OpenRouter pour saisir du texte), ou gratuit |

**Pourquoi pas JEV seul :** son éditeur le dit fort sur les décisions immédiates et faible sur les raisonnements à plusieurs niveaux, les nombres et les dates. Il favorise aussi la première option, et un contenu hostile peut orienter sa réponse. Il ne décide donc jamais du danger d'un script ni de la portée d'un pentest.

**Confidentialité :** les requêtes partent directement chez TypeSafe, aux États-Unis. Sa politique exclut l'entraînement sur tes requêtes, mais ne donne pas de durée de conservation. Les agents ont pour consigne de n'y envoyer ni secret, ni donnée personnelle, ni code privé, ni résultat de pentest. Aucun contrôle technique ne le garantit (section 4).

**Connexion :** tape ta clé TypeSafe avec `.\mcp-scraping.ps1`. Elle est stockée en clair dans `~/.copilot/decision/.env`. Sans clé, les agents passent à l'outil suivant. `jev` est un petit serveur local (`jev_mcp.py`). `install.ps1` l'ajoute aussi au fichier MCP de VS Code si VS Code est présent.

**Navigateur :** `jev-browser` utilise un profil Chrome dédié, sans tes comptes, sauf avec `--my-chrome`. La version est figée sur le commit `8251e27`, et la télémétrie de `browser-harness` est coupée. Il utilise la même clé TypeSafe que les décisions.

## 5 ter. Pentest

`cop-pentest` ouvre une session avec l'agent `pentest`. Il attaque, exploite et prouve les failles, propose les correctifs, rejoue les attaques et écrit son rapport dans `pentest-<date>/`.

**Portée :** les cibles que tu nommes, celles de `pentest-scope.txt` à la racine du projet, et les cibles locales. Une redirection vers un tiers est hors portée. Cette règle est une consigne, pas un blocage technique.

N'attaque que ce dont tu as la responsabilité : une application hébergée reste soumise aux règles de son hébergeur. Travaille de préférence dans WSL, Docker ou une machine virtuelle : les outils offensifs déclenchent souvent l'antivirus et le contrôle intelligent des applications, et ce kit n'ajoute aucune exclusion. Évite la production pour les tests destructifs.

## 6. Limites que le kit ne peut pas lever

- Une stratégie d'organisation (licence Business ou Enterprise) peut bloquer `--yolo` ou imposer le bac à sable.
- Une règle d'interdiction l'emporte toujours sur `--yolo`, par exemple une option `--deny-tool` passée à la main. Le kit ne nettoie que le fichier de réglages utilisateur, pas ceux des dépôts (`.github/copilot/settings.json`).
- Windows garde ses limites : sans élévation administrateur, Copilot n'a que les droits de ton compte.
- Les modèles et efforts disponibles dépendent de l'abonnement. Le mode Auto refuse `--reasoning-effort` : pour imposer un effort, relance `.\install.ps1 -Model <nom> -Effort <niveau>`.
- Une skill ne crée pas de connexion : Jira, Confluence ou GitLab demandent un accès réel (voir section 8).
- Le scraping reste soumis au droit et aux conditions des sites. Les données personnelles relèvent du RGPD. L'agent Scraper ne force ni identifiant, ni contrôle d'accès, ni paywall.
- Aucun réglage ne lève les refus du modèle ni les conditions d'utilisation de GitHub Copilot : c'est le cas le plus probable en pentest offensif.

## 7. Architecture

```text
UTILISATEUR → ARCHITECT : comprend, planifie, délègue, consolide
                 ├─ Sources : source-access, file-intelligence, github, jira, confluence, knowledge-management
                 └─ Spécialistes : frontend, backend, database, devops, security, scraper, pentest,
                                   testing-strategy, qa-automation, code-review, documentation
DÉCISION : JEV, rubber duck, sequential-thinking, Jev Ultrafast, pour tous
```

- **Agent :** profil spécialisé, dans `agents/<nom>.agent.md`.
- **Skill :** méthode réutilisable, dans `skills/<nom>/SKILL.md`, chargée à la demande. Toutes sont donc installées quelle que soit la pile. `backend` et `frontend` couvrent aussi les autres langages détectés.
- **MCP :** outils techniques fournis au runtime. Le serveur `github-mcp-server` est intégré.
- **Instructions :** `copilot-instructions.md`, chargé dans toutes les sessions.

## 8. Intégrations

Le fichier du CLI est `~/.copilot/mcp-config.json`, à gérer avec `copilot mcp add`, `list` et `get`. Le fichier `%APPDATA%\Code\User\mcp.json` concerne VS Code, pas le CLI.

Après avoir ajouté un serveur, contrôle séparément avec `/mcp` : présence, activation, état en ligne, outils, authentification. Le bouton *Authenticate* ne prouve pas que l'authentification a réussi : seul un appel réel à un outil le prouve.

## 9. Tests

**Ce qui a déjà été vérifié (poste de test, 3 novembre 2026) :**

- L'installation complète, sa relance et l'arrêt sur un `settings.json` corrompu, dans un dossier temporaire.
- `tests/test_engine.py` : reprise, robots, erreurs, dédoublonnage, exports.
- Une vraie session Copilot : l'agent `scraper` se charge.
- `tests/test_jev_browser.py` : vrai clic dans Chrome sur une page locale, réponse du modèle simulée.
- `tests/test_jev_mcp.py` : serveur `jev` contre une fausse API TypeSafe (format des requêtes, clé, erreurs, nouvelles tentatives) et en processus réel sur son canal MCP.

**Pas encore vérifié, faute de compte ou de session réelle :** un vrai appel à TypeSafe, le chargement du serveur `jev` en session, le chargement de `sequential-thinking`, le rubber duck en autopilot, l'agent `pentest` en session.

**Ce qu'il te reste à vérifier, car cela consomme des crédits ou demande tes comptes :**

```powershell
# 1. La délégation fonctionne : smoke.md doit montrer au moins deux sous-agents lancés
copr "Ajoute une fonction utilitaire avec ses tests. Délègue l'implémentation au spécialiste concerné puis la revue à code-review, et cite les agents réellement appelés." --share smoke.md

# 2. Le scraping fonctionne de bout en bout
copr "Délègue à scraper : extrais le titre de https://example.com avec un outil MCP, range le résultat selon la skill data-organization et cite l'outil utilisé."

# 3. JEV répond : une décision coûte une fraction de centime
copr "Utilise jev : appelle list_models, puis run_decision avec le state {\"team\":\"small\"} et une question choice entre postgresql et mongodb. Montre la réponse brute."
```

Dans une session interactive, `/tasks` montre les sous-agents, `/env` les agents et skills chargés, `/mcp` l'état des serveurs. Si aucun sous-agent n'apparaît, la délégation ne fonctionne pas dans cette version : l'Architect doit l'annoncer et enchaîner les rôles lui-même.

Pour relancer les tests locaux, sans crédits, depuis la racine du kit installé :

```powershell
& "$HOME\.copilot\scraper\venv\Scripts\python.exe" .\tests\test_engine.py
& "$HOME\.copilot\decision\venv\Scripts\python.exe" .\tests\test_jev_mcp.py
& "$HOME\.copilot\decision\venv\Scripts\python.exe" .\tests\test_jev_browser.py   # ouvre Chrome
```

## 10. Retour arrière

Sauvegardes : `~/.copilot/backups/architecte-<date>/` pour la plupart des fichiers, `~/.copilot/backups/mcp-config-<date>.json` pour la configuration MCP. Ces copies peuvent contenir tes clés en clair : ne les partage pas. `statusline.ps1` est réécrit sans copie à chaque installation.

Prends la sauvegarde la plus ancienne pour retrouver l'état d'avant le kit.

1. Recopie `settings.json` et `copilot-instructions.md` depuis `architecte-<date>/`, et `mcp-config-<date>.json` sous le nom `mcp-config.json`, vers `~/.copilot/`. Supprime ceux qui n'existaient pas avant, ou retire seulement le bloc `copilot-architecte` des instructions.
2. Retire le bloc `copilot-architecte` de ton profil PowerShell, ou restaure `powershell-profile.ps1` depuis la sauvegarde.
3. Supprime les dossiers `~/.copilot/scraper` et `~/.copilot/decision`, ainsi que `~/.copilot/statusline.ps1` et `~/.copilot/architecte-manifest.json`.
4. Pour enlever les agents et skills, supprime leurs fichiers dans `~/.copilot/agents` et `~/.copilot/skills`. La liste exacte est dans `architecte-manifest.json` : lis-la avant de le supprimer.
5. Si VS Code est présent, retire `jev` de `%APPDATA%\Code\User\mcp.json`, ou restaure `vscode-mcp.json` depuis la sauvegarde.

Pour réduire les droits le temps d'une session, utilise `/permissions`.

## 11. Installation par une IA

La procédure est dans `AGENTS.md`. Le `README.md` donne le texte à coller. Lance l'IA en mode sans restriction : elle le demande une fois si ce n'est pas le cas.

## 12. Historique du kit

- **2.2 sans Gardien :** retrait du Gardien, de son hook, du contrôle du dossier au lancement, de la skill `script-guard` et de leurs tests. Ajout de la ligne d'état, du choix entre mise à jour et réinitialisation, du manifeste du kit et de la fenêtre dédiée aux clés.
- **2.2 :** dépôt prêt pour GitHub, installation en une commande, aide à la décision (JEV par appel direct à TypeSafe, rubber duck, sequential-thinking, Jev Ultrafast) pour tous les agents, agent Pentest et `cop-pentest`, plus aucune question posée à l'utilisateur.
- **2.1 :** agent Scraper, 7 skills, 11 serveurs MCP possibles, moteur de scraping en masse, Gardien. `COPILOT_ALLOW_ALL` n'est plus permanent : il est posé à chaque lancement, après la vérification du dossier.
- **2.0 :** fichiers réels d'agents et de skills, installateur et vérificateur, mode pleine puissance, retrait de l'historique personnel.
- **1.0 :** cahier des charges.
