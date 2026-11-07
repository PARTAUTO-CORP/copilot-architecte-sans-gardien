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

Tu dois être sur Windows 10 ou 11, ou sur Linux (x64 ou arm64), dans le dossier qui contient `installer.cmd` et `installer.sh`. Sinon, clone le dépôt qu'on t'a indiqué ou télécharge son ZIP, puis place-toi dedans. Sur un autre système (macOS…), arrête-toi et dis-le.

Lis `bootstrap.ps1` et `install.ps1` pour savoir ce que tu vas lancer, et `installer.sh` sous Linux.

## 2. Installe

Sous Windows :

```bat
.\installer.cmd -NoPrompt
```

Sous Linux (PC ou VPS, avec ou sans bureau graphique), regarde d'abord qui tu es avec `id -u`.

**Tu n'es pas root :**

```bash
bash installer.sh -NoPrompt
```

Avec `-NoPrompt`, `sudo` n'attend jamais de mot de passe. Sans `sudo` sans mot de passe, la partie système (Google Chrome, ICU, module `venv`) est sautée avec un avertissement `[!!] No root access` ; tout le reste s'installe dans `~/.local`, Python compris. Note-le pour l'étape 4.

**Tu es root (fréquent sur un VPS) :** demande une seule fois à la personne si tu crées un utilisateur dédié `copilot` pour le kit (recommandé : en root, Copilot a la main sur tout le serveur et le navigateur Jev ne peut pas démarrer Chrome). Si elle accepte, depuis le dossier du kit :

```bash
bash installer.sh -SystemOnly
id copilot >/dev/null 2>&1 || useradd -m -s /bin/bash copilot
# SSH : les mêmes clés que root, car les VPS refusent souvent la connexion SSH par mot de passe
[ -f /root/.ssh/authorized_keys ] && install -d -m 700 -o copilot -g copilot /home/copilot/.ssh && install -m 600 -o copilot -g copilot /root/.ssh/authorized_keys /home/copilot/.ssh/
cp -r "$PWD" /home/copilot/ && chown -R copilot: "/home/copilot/$(basename "$PWD")"
su - copilot -c "cd '$(basename "$PWD")' && bash installer.sh -NoPrompt"
```

Ne choisis pas de mot de passe pour ce compte : la personne le fera à l'étape 4. Si elle refuse, lance `bash installer.sh -NoPrompt` en root et mentionne le risque dans le rapport.

Sous Linux, tes propres commandes ne relisent pas le `PATH` modifié : appelle PowerShell par son chemin, `~/.local/bin/pwsh ./verifier.ps1`, et pour l'utilisateur dédié `su - copilot -c "cd '<dossier du kit>' && ~/.local/bin/pwsh ./verifier.ps1"`.

Chaque commande installe ce qui manque (PowerShell 7, Python, Node, Copilot CLI), puis le kit, puis lance le contrôle. Le téléchargement Python pèse environ 200 Mo, compte quelques minutes. Elle peut se relancer sans risque, et chaque fichier modifié est d'abord sauvegardé dans `~/.copilot/backups/`.

Avec `-NoPrompt`, c'est une mise à jour : les réglages et fichiers personnels restent. N'ajoute `-Reset` que si la personne demande une réinitialisation.

Résultat attendu : `RESULT: all checks OK`, code de sortie 0.

## 3. En cas de problème

| Symptôme | Que faire |
|---|---|
| Un `KO` sur un prérequis | Installe-le depuis le site de l'éditeur, puis relance l'étape 2 |
| Linux : `Python 3.12 or newer with venv is still missing` | Le Python autonome (uv) n'a pas pu s'installer : relis l'erreur, souvent le réseau. Installe Python 3.12+ avec son module `venv`, puis relance |
| Linux : `PowerShell 7 does not start` | La bibliothèque ICU manque : `bash installer.sh -SystemOnly` en root, puis relance l'étape 2 |
| Linux : `Google Chrome is not installed` | Sans root : étape 4. Sur arm64, Google ne fournit pas Chrome : `playwright` et Jev ne fonctionnent pas, le moteur local et les serveurs MCP distants si |
| Linux : `cop` ou `copilot` introuvable | Ouvre un nouveau terminal (le `PATH` est relu), puis tape `pwsh` |
| `Python packages ... failed` | Relis l'erreur de pip. Le contrôle intelligent des applications peut bloquer un paquet : ne le désactive pas, signale-le |
| `settings.json` illisible | Il est corrompu : l'installation s'arrête pour ne pas l'écraser. Répare le JSON ou restaure une sauvegarde, puis relance |
| Copilot plus récent que `1.0.105` et un réglage refusé | Compare avec `copilot help config` et `copilot help permissions`, puis adapte le nom dans `install.ps1` |
| Ton outil ou un contrôle de sécurité refuse une commande | Ne cherche pas à le contourner. Demande à la personne de lancer elle-même la commande de l'étape 2 dans son terminal, puis reprends à l'étape 4 |
| Un autre `KO` de `verifier.ps1` | Corrige la cause indiquée, puis relance `./verifier.ps1` dans PowerShell 7 (sous Linux : `~/.local/bin/pwsh ./verifier.ps1`) |
| Linux : `apt` reste bloqué ou échoue au premier démarrage du VPS | Les mises à jour automatiques tiennent le verrou ; l'installation attend jusqu'à 10 minutes. Si Chrome manque ensuite, relance l'étape 2 |

## 4. Termine avec la personne

Ces actions lui reviennent, car elles demandent son compte, ses mots de passe ou ses clés. **Ne lui demande jamais une clé ni un mot de passe dans la conversation et n'en lis aucun.** Donne-lui cette liste, en gardant seulement ce qui la concerne.

D'abord, sous Linux :

- Si tu as créé l'utilisateur `copilot` : `passwd copilot` dans son terminal root, nécessaire pour ouvrir le bureau graphique (xrdp, VNC) en tant que `copilot`. En SSH, il se connecte avec ses clés habituelles (`ssh copilot@<serveur>`) ; depuis un terminal root, `su - copilot` suffit. Toute la suite se fait dans une session `copilot`.
- Si l'installation a signalé `No root access` : `bash installer.sh` dans son terminal, depuis le dossier du kit. Il demande son mot de passe `sudo` pour installer Chrome, puis le mode (Entrée) et ses clés, ce qui couvre aussi le point 2.

Ensuite, partout :

1. Si le contrôle signale que Copilot n'est pas connecté : `copilot login`. Sans bureau, il affiche un code à saisir sur github.com/login/device depuis n'importe quel appareil.
2. Pour taper ses clés : `./mcp-scraping.ps1` dans son terminal PowerShell 7, dont la clé TypeSafe de JEV (console.typesafe.ai/keys). Sous Windows une fenêtre dédiée s'ouvre, sous Linux les questions restent dans le terminal. Entrée permet de passer une clé.
3. Dans un nouveau terminal PowerShell 7 (sous Linux : ouvrir un terminal et taper `pwsh`) : `cop`, puis `/env`, `/agents` et `/mcp`, pour confirmer le chargement et se connecter à Firecrawl, TinyFish, Olostep et Apify.
4. Sous Windows, si l'installation signale que la protection en temps réel de Windows Defender est coupée, la réactiver dans Sécurité Windows.

## 5. Rapport final

Écris un rapport court : ce qui était présent avant, ce qui a été installé, le résultat de `verifier.ps1`, les avertissements, et la liste de l'étape 4 restant à faire. Rappelle en une phrase que `cop` donne à Copilot tous les droits du compte utilisateur (Windows ou Linux), sans confirmation, et qu'aucun Gardien ne contrôle ses commandes dans cette version. Sur un VPS, ajoute : le compte utilisé (dédié ou root), si Chrome est installé, et le conseil de n'ouvrir que les ports nécessaires.

Ne présente comme vérifié que ce que tu as réellement observé, et n'affiche jamais la valeur d'un secret. Pour tester en profondeur, les commandes sont à la section 9 de `docs/REFERENCE_TECHNIQUE.md` ; elles consomment des crédits, ne les lance que si on te le demande.
