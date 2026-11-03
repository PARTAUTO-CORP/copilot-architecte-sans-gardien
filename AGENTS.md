# Installer Copilot Architecte : procédure pour une IA

Si on te demande d'installer ce dépôt, suis ces étapes dans l'ordre, jusqu'au bout. La personne a demandé cette installation en te donnant ce dépôt. Pose le moins de questions possible et réponds en français.

## 0. Passe en mode sans restriction

Une installation fluide demande de lancer des commandes et d'écrire dans le profil utilisateur sans demande d'autorisation à chaque fois.

Si ta session est déjà sans restriction, continue. Sinon, demande une seule fois à la personne de te relancer ainsi, depuis ce dossier :

| IA | Commande |
|---|---|
| GitHub Copilot CLI | `copilot --yolo` |
| Claude Code | `claude --dangerously-skip-permissions` |
| Codex CLI | `codex --yolo` |
| Cursor CLI | `cursor-agent --force` |
| Autre | Le mode qui accepte tout sans confirmation (auto-approve, YOLO, full access) |

Si la personne ne peut pas ou ne veut pas, continue quand même : elle validera chaque demande.

## 1. Vérifie où tu es

Tu dois être sur Windows 10 ou 11, dans le dossier qui contient `installer.cmd`. Sinon, clone le dépôt qu'on t'a indiqué ou télécharge son ZIP, puis place-toi dedans. Sur un autre système, arrête-toi et dis-le : le kit est écrit pour Windows.

Lis `bootstrap.ps1` et `install.ps1` pour savoir ce que tu vas lancer.

## 2. Installe

```bat
.\installer.cmd -NoPrompt
```

Depuis PowerShell, c'est la même commande. Elle installe ce qui manque (PowerShell 7, Python, Node, Copilot CLI), puis le kit, puis lance le contrôle. Le téléchargement Python pèse environ 200 Mo, compte quelques minutes. Elle peut se relancer sans risque, et chaque fichier modifié est d'abord sauvegardé dans `~/.copilot/backups/`.

Avec `-NoPrompt`, c'est une mise à jour : les réglages et fichiers personnels restent. N'ajoute `-Reset` que si la personne demande une réinitialisation.

Résultat attendu : `RESULT: all checks OK`, code de sortie 0.

## 3. En cas de problème

| Symptôme | Que faire |
|---|---|
| Un `KO` sur un prérequis | Installe-le depuis le site de l'éditeur, puis relance l'étape 2 |
| `Python packages ... failed` | Relis l'erreur de pip. Le contrôle intelligent des applications peut bloquer un paquet : ne le désactive pas, signale-le |
| `settings.json` illisible | Il est corrompu : l'installation s'arrête pour ne pas l'écraser. Répare le JSON ou restaure une sauvegarde, puis relance |
| Copilot plus récent que `1.0.105` et un réglage refusé | Compare avec `copilot help config` et `copilot help permissions`, puis adapte le nom dans `install.ps1` |
| Ton outil ou un contrôle de sécurité refuse une commande | Ne cherche pas à le contourner. Demande à la personne de lancer elle-même `.\installer.cmd -NoPrompt` dans son terminal, puis reprends à l'étape 4 |
| Un autre `KO` de `verifier.ps1` | Corrige la cause indiquée, puis relance `.\verifier.ps1` dans PowerShell 7 |

## 4. Termine avec la personne

Ces actions lui reviennent, car elles demandent son compte ou ses clés. **Ne lui demande jamais une clé dans la conversation et n'en lis aucune.** Donne-lui cette liste :

1. Si le contrôle signale que Copilot n'est pas connecté : `copilot login`.
2. Pour taper ses clés : `.\mcp-scraping.ps1` dans son terminal PowerShell 7, dont la clé TypeSafe de JEV (console.typesafe.ai/keys). Une fenêtre dédiée s'ouvre, et Entrée permet de passer une clé.
3. Dans un nouveau terminal PowerShell 7 : `cop`, puis `/env`, `/agents` et `/mcp`, pour confirmer le chargement et se connecter à Firecrawl, TinyFish, Olostep et Apify.
4. Si l'installation signale que la protection en temps réel de Windows Defender est coupée, la réactiver dans Sécurité Windows.

## 5. Rapport final

Écris un rapport court : ce qui était présent avant, ce qui a été installé, le résultat de `verifier.ps1`, les avertissements, et la liste de l'étape 4 restant à faire. Rappelle en une phrase que `cop` donne à Copilot tous les droits du compte Windows, sans confirmation, et qu'aucun Gardien ne contrôle ses commandes dans cette version.

Ne présente comme vérifié que ce que tu as réellement observé, et n'affiche jamais la valeur d'un secret. Pour tester en profondeur, les commandes sont à la section 9 de `docs/REFERENCE_TECHNIQUE.md` ; elles consomment des crédits, ne les lance que si on te le demande.
