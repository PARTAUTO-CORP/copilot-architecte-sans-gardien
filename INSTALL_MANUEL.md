# Installation manuelle, de A à Z

Ce guide fait à la main tout ce que fait `installer.cmd`. Chaque étape dit quoi faire, pourquoi, et comment vérifier. Tu peux aussi copier-coller n'importe quelle étape à une IA : les blocs se suffisent à eux-mêmes.

**Le plus simple reste la voie assistée** (partie A). La partie B détaille chaque fichier, si tu veux tout contrôler. La partie C adapte le kit à une autre IA que Copilot.

**Une IA peut tout faire pour toi :** ouvre-la d'abord en mode sans restriction, comme indiqué dans le [README](README.md), sinon elle sera freinée à chaque commande.

## Ce que l'installation change sur ton PC

| Emplacement | Ce qui change |
|---|---|
| `~/.copilot/agents`, `skills` | Ajoute les 12 agents et les 28 skills. Tes autres agents et skills restent |
| `~/.copilot/scraper`, `decision` | Ajoute le moteur de scraping, le serveur `jev`, le navigateur Jev et leurs environnements Python |
| `~/.copilot/copilot-instructions.md` | Ajoute les règles communes dans un bloc repéré. Le reste du fichier ne change pas |
| `~/.copilot/settings.json` | Lève les verrous de Copilot. Tes autres réglages restent |
| `~/.copilot/mcp-config.json` | Déclare les serveurs MCP. Tes autres serveurs restent |
| `~/.copilot/statusline.ps1` | Ajoute la ligne d'état : modèle, dossier, branche, contexte, requêtes, durée |
| `~/.copilot/architecte-manifest.json` | Liste les fichiers du kit, pour pouvoir retirer ceux devenus obsolètes |
| Profil PowerShell (`$PROFILE.CurrentUserAllHosts`) | Ajoute `cop`, `copr` et `cop-pentest` dans un bloc repéré |
| `%APPDATA%\Code\User\mcp.json` | Ajoute `jev`, seulement si VS Code est présent |

L'installation retire aussi le Gardien d'une version précédente et la variable utilisateur permanente `COPILOT_ALLOW_ALL`. Tes fichiers modifiés sont d'abord copiés dans `~/.copilot/backups/`, sauf `statusline.ps1`, réécrit à chaque installation.

**Avant de continuer, lis [À lire avant d'installer](README.md#à-lire-avant-dinstaller) :** une fois installé, `cop` agit avec tous les droits de ton compte Windows, sans confirmation.

## Partie A : par étapes, avec les scripts

### Étape 1 : récupérer le dossier

Avec Git :

```powershell
cd $HOME
git clone https://github.com/TON-COMPTE/copilot-architecte
cd copilot-architecte
```

Sans Git : sur GitHub, choisis **Code > Download ZIP**, décompresse, et ouvre un terminal dans le dossier. Dans ce cas, débloque les fichiers, que Windows marque comme venus d'Internet :

```powershell
Get-ChildItem -Recurse -File | Unblock-File
```

### Étape 2 : installer les prérequis

Vérifie ce que tu as déjà :

```powershell
$PSVersionTable.PSVersion; pwsh --version; python --version; node --version; copilot --version
```

Il faut PowerShell 7.3+, Python 3.12+ et Node 24+. Installe seulement ce qui manque, puis **ouvre un nouveau terminal PowerShell 7 (`pwsh`)** pour la suite :

```powershell
winget install --id Microsoft.PowerShell --exact
winget install --id Python.Python.3.12 --exact
winget install --id OpenJS.NodeJS.LTS --exact
npm install -g @github/copilot
```

### Étape 3 : connecter Copilot

```powershell
copilot login
```

Ton navigateur s'ouvre pour autoriser l'accès avec le compte GitHub qui a l'abonnement.

### Étape 4 : installer le kit

```powershell
pwsh -ExecutionPolicy Bypass -File .\install.ps1
```

Le script pose d'abord une question :

| Choix | Effet |
|---|---|
| `1` ou Entrée : mise à jour | Ajoute et met à jour les fichiers du kit. Garde tes réglages et tes fichiers. C'est le bon choix dans la plupart des cas |
| `2` : réinitialisation | Fait la même chose, et retire aussi les anciens fichiers du kit listés dans son manifeste. Tape `REINITIALISER` pour confirmer |

Une fenêtre PowerShell 7 s'ouvre ensuite pour tes clés (étape 5). Elle se ferme à la fin, puis l'installation reprend.

| Option | Effet |
|---|---|
| `-NoPrompt` | Ne pose aucune question et n'ouvre pas la fenêtre des clés. Le mode est alors la mise à jour |
| `-Reset` | Réinitialise. Avec `-NoPrompt`, aucune confirmation n'est demandée |
| `-Effort xhigh` | Effort utilisé avec un modèle fixé par `-Model` (`high` par défaut). En mode Auto, Copilot choisit lui-même |
| `-Model <nom>` | Fixe un modèle disponible sur ton abonnement |
| `-SkipScraperDeps` | Saute le téléchargement Python, d'environ 200 Mo |

### Étape 5 : ajouter tes clés

Si tu as déjà rempli la fenêtre de l'étape 4, passe à l'étape 6. Pour ajouter ou changer une clé plus tard :

```powershell
pwsh -ExecutionPolicy Bypass -File .\mcp-scraping.ps1
```

Une fenêtre dédiée s'ouvre. Colle chaque clé dans le champ masqué, ou appuie sur Entrée pour passer : une clé déjà enregistrée reste en place. Si la clé TypeSafe manque, la page de TypeSafe s'ouvre dans ton navigateur. La clé OpenRouter n'est demandée qu'après une clé TypeSafe.

| Clé | Où la trouver | Sert à |
|---|---|---|
| TypeSafe | console.typesafe.ai/keys | Décisions JEV et navigateur Jev |
| OpenRouter | openrouter.ai/keys | Saisie de texte dans le navigateur Jev |
| Crawlbase, Decodo, Oxylabs, ScrapingBee, Bright Data | Tableau de bord de chaque service | Sites qui bloquent les robots |
| Olostep | olostep.com/dashboard/api-keys | Facultatif : la connexion dans `/mcp` suffit |

**Ne donne jamais une clé à une IA dans une conversation.** Elles sont stockées en clair dans `~/.copilot/mcp-config.json` et `~/.copilot/decision/.env`, et les copies de `mcp-config.json` dans `~/.copilot/backups/` les contiennent aussi : ne partage aucun de ces fichiers. Pour retaper la clé TypeSafe ou OpenRouter, supprime `decision\.env` et relance le script.

### Étape 6 : contrôler

Ouvre un **nouveau** terminal PowerShell 7, puis dans le dossier du kit :

```powershell
pwsh -ExecutionPolicy Bypass -File .\verifier.ps1
```

Le dernier message doit être `RESULT: all checks OK`. Une ligne `[!!]` est un avertissement, une ligne `[KO]` indique ce qu'il faut corriger.

### Étape 7 : démarrer et connecter les services

```powershell
cop
```

Dans la session, tape `/env`, `/agents` (12 agents) et `/mcp`. Dans `/mcp`, connecte-toi à Firecrawl, TinyFish, Olostep et Apify si tu les utilises.

### Étape 8 : essayer

Ces essais consomment quelques crédits :

```powershell
# JEV répond, si ta clé TypeSafe est en place
copr "Utilise jev : appelle list_models, puis run_decision avec le state {\"team\":\"small\"} et une question choice entre postgresql et mongodb. Montre la réponse brute."
```

## Partie B : chaque action en détail

Fais cette partie seulement si tu ne veux pas lancer `install.ps1`, après les étapes 1 à 3 de la partie A. `~/.copilot` désigne le dossier `.copilot` de ton profil Windows, `%USERPROFILE%\.copilot`. Les commandes se lancent dans PowerShell 7, à la racine du kit, et une seule fois : contrairement à `install.ps1`, certaines ajouteraient leur bloc en double. **Si le dossier `.copilot` existe déjà, sauvegarde-le d'abord :**

```powershell
Copy-Item "$HOME\.copilot" "$HOME\.copilot.sauvegarde" -Recurse
```

Cette voie ne crée pas `architecte-manifest.json`. Il sera créé au prochain `install.ps1`.

### 1. Copier agents, skills, moteur et décisions

Ils apportent les rôles, les méthodes et les outils locaux.

```powershell
foreach ($dossier in 'agents', 'skills', 'scraper', 'decision') {
    New-Item -ItemType Directory -Force "$HOME\.copilot\$dossier" | Out-Null
    Copy-Item ".\payload\$dossier\*" "$HOME\.copilot\$dossier" -Recurse -Force
}
```

### 2. Ajouter les règles communes

Copilot les charge dans toutes les sessions. Ajoute le contenu de `payload/copilot-instructions.md` à la fin de `~/.copilot/copilot-instructions.md`, entre deux lignes de repère qui permettront de le retrouver :

```powershell
$cible = "$HOME\.copilot\copilot-instructions.md"
$bloc = "# >>> copilot-architecte >>>`n" + (Get-Content .\payload\copilot-instructions.md -Raw).Trim() + "`n# <<< copilot-architecte <<<"
Add-Content -LiteralPath $cible -Value "`n$bloc"
```

### 3. Régler Copilot

Ajoute ces clés dans `~/.copilot/settings.json`, sans retirer les tiennes :

```json
{
  "defaultPermissionMode": "allow-all",
  "defaultMode": "interactive",
  "stayInAutopilot": false,
  "experimental": true,
  "memory": true,
  "askUser": true,
  "continueOnAutoMode": true,
  "keepAlive": "busy",
  "powershellFlags": ["-NoProfile", "-NoLogo", "-ExecutionPolicy", "Bypass"],
  "deniedUrls": [],
  "sandbox": { "enabled": false },
  "footer": { "showQuota": true, "showContext": true },
  "subagents": { "agents": { "rubber-duck": { "autoInvoke": true } } }
}
```

Si ton fichier contient `permissions.disableBypassPermissionsMode`, retire cette clé : elle empêcherait `--yolo` de fonctionner.

| Réglage | Effet |
|---|---|
| `defaultPermissionMode`, `sandbox`, `deniedUrls` | Plus d'autorisation à donner ni de verrou |
| `defaultMode`, `stayInAutopilot`, `continueOnAutoMode` | Session interactive, avec bascule de modèle en cas de limite de débit |
| `askUser: true` | L'agent peut demander s'il faut changer le niveau d'effort |
| `powershellFlags` | Les scripts PowerShell ne sont plus bloqués |
| `subagents...autoInvoke` | Second avis automatique d'une autre famille de modèles |
| `keepAlive`, `experimental`, `memory` | PC éveillé pendant le travail, fonctions expérimentales, mémoire entre les sessions |
| `footer` | Affiche le quota et le contexte en bas de la session |

Ajoute ensuite la ligne d'état, que `verifier.ps1` contrôle aussi. Ce bloc reprend le script écrit dans `install.ps1` et remplace un éventuel réglage `statusLine` existant :

```powershell
$script = "$HOME\.copilot\statusline.ps1"
$corps = [regex]::Match((Get-Content .\install.ps1 -Raw), "(?s)statusLineScriptBody = @'\r?\n(.*?)\r?\n'@").Groups[1].Value
Set-Content -LiteralPath $script -Value $corps -NoNewline
$reglages = Get-Content "$HOME\.copilot\settings.json" -Raw | ConvertFrom-Json -AsHashtable
$reglages['statusLine'] = [ordered]@{ type = 'command'; command = "pwsh -NoProfile -ExecutionPolicy Bypass -File `"$script`""; padding = 1; refreshInterval = 5 }
$reglages | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath "$HOME\.copilot\settings.json"
```

### 4. Retirer un ancien Gardien

S'il a déjà été installé, son hook continuerait de refuser des commandes :

```powershell
Remove-Item "$HOME\.copilot\hooks\architecte-gardien.json" -ErrorAction SilentlyContinue
Remove-Item "$HOME\.copilot\gardien", "$HOME\.copilot\skills\script-guard" -Recurse -Force -ErrorAction SilentlyContinue
```

### 5. Créer les commandes `cop`, `copr` et `cop-pentest`

Elles apportent les options qui n'existent pas en réglage permanent. Colle ce bloc dans une session PowerShell 7 :

```powershell
# Avec un modèle fixé, ajoute --model <nom> --reasoning-effort high : le mode Auto refuse cette option.
$options = '--yolo --experimental --enable-all-github-mcp-tools --allow-all-mcp-server-instructions'
$optionsAuto = '--autopilot --no-ask-user --max-autopilot-continues 999999'
$bloc = @"
# >>> copilot-architecte >>>
function Invoke-CopilotArchitecte {
    `$env:COPILOT_ALLOW_ALL = 'true'
    try { copilot @args } finally { Remove-Item Env:COPILOT_ALLOW_ALL -ErrorAction SilentlyContinue }
}
function cop { Invoke-CopilotArchitecte $options --agent architect @args }
function copr { Invoke-CopilotArchitecte $options $optionsAuto --agent architect --enable-memory -p `$args[0] @(`$args | Select-Object -Skip 1) }
function cop-pentest { Invoke-CopilotArchitecte $options --agent pentest @args }
# <<< copilot-architecte <<<
"@
New-Item -ItemType Directory -Force (Split-Path $PROFILE.CurrentUserAllHosts) | Out-Null
Add-Content -LiteralPath $PROFILE.CurrentUserAllHosts -Value "`n$bloc"
```

Ne rends pas `COPILOT_ALLOW_ALL` permanent : tout dossier serait alors accepté sans question, même hors de `cop`.

### 6. Déclarer les serveurs MCP

Ce script fusionne la configuration et garde tes autres serveurs. Le remplacer à la main n'apporte rien, car il ne fait qu'écrire ce fichier :

```powershell
pwsh -ExecutionPolicy Bypass -File .\mcp-scraping.ps1 -NoPrompt
```

| Serveur | Accès | Sert à |
|---|---|---|
| `jev` | Clé TypeSafe, local | Décisions rapides |
| `sequential-thinking` | Gratuit, local | Raisonnement structuré |
| `playwright` | Gratuit, local | Navigateur |
| `firecrawl`, `tinyfish`, `olostep`, `apify` | Connexion dans `/mcp` | Scraping |
| `jina` | Sans compte pour une partie des outils | Lecture de pages |
| `crawlbase`, `decodo`, `oxylabs`, `scrapingbee`, `brightdata` | Clé | Sites qui bloquent les robots |

Pour Copilot dans VS Code, ajoute le serveur de décision à `%APPDATA%\Code\User\mcp.json` :

```powershell
$python = "$HOME\.copilot\decision\venv\Scripts\python.exe"
$serveur = "$HOME\.copilot\decision\jev_mcp.py"
code --add-mcp (@{ name = 'jev'; type = 'stdio'; command = $python; args = @($serveur) } | ConvertTo-Json -Compress)
```

### 7. Créer les environnements Python

Le moteur de scraping et le navigateur Jev ont chacun le leur.

```powershell
foreach ($partie in 'scraper', 'decision') {
    python -m venv "$HOME\.copilot\$partie\venv"
    & "$HOME\.copilot\$partie\venv\Scripts\python.exe" -m pip install -r "$HOME\.copilot\$partie\requirements.txt"
}
```

### 8. Retirer l'ancien réglage permanent

```powershell
[Environment]::SetEnvironmentVariable('COPILOT_ALLOW_ALL', $null, 'User')
```

Reprends ensuite à l'étape 5 de la partie A.

## Partie C : adapter le kit à une autre IA

Le kit est écrit et testé pour GitHub Copilot CLI. Les agents, skills et règles sont en Markdown et se transposent, mais les réglages dépendent de chaque outil. **Rien de cette partie n'a été testé.** Colle ce texte à l'IA visée, depuis le dossier du kit :

```text
Adapte le kit présent dans ce dossier à toi-même, l'IA que j'utilise. Lance-toi en mode sans restriction si besoin.

1. Lis AGENTS.md, INSTALL_MANUEL.md, docs/REFERENCE_TECHNIQUE.md et le dossier payload/.
2. Cherche dans ta documentation officielle où vont les agents, les skills, les instructions globales, les serveurs MCP et les hooks.
3. Installe-y les agents de payload/agents et les skills de payload/skills, en adaptant leur en-tête à ton format.
4. Ajoute les règles de payload/copilot-instructions.md à tes instructions globales.
5. Déclare les serveurs MCP listés dans mcp-scraping.ps1 dans ton format, avec jev_mcp.py pour jev.
6. Ne change aucun réglage sans savoir ce qu'il fait. Sauvegarde chaque fichier avant de le modifier.
7. Rapport : ce qui fonctionne et a été testé, ce qui n'a pas d'équivalent chez toi. Ne me demande jamais une clé dans la conversation.
```

## Problèmes fréquents

| Problème | Solution |
|---|---|
| `cop` n'est pas reconnu | Ouvre un nouveau terminal `pwsh`. Le profil ne se charge pas dans l'ancien Windows PowerShell |
| L'installation s'arrête sur `settings.json` ou `mcp-config.json` | Le fichier n'est pas un JSON valide. Répare-le ou restaure-le depuis `~/.copilot/backups/`, puis relance : l'arrêt évite de l'écraser |
| `Installation cancelled: choose 1 or 2` | Relance et réponds `1`, `2` ou Entrée à la première question |
| `statusLine` en `KO` après la partie B | Applique le bloc de la ligne d'état, à la fin de la section 3 de la partie B |
| Le navigateur Jev répond `Chrome not found` | Installe Google Chrome, ou laisse les agents passer par `playwright` |
| « L'exécution de scripts est désactivée » | Lance `Get-ChildItem -Recurse -File \| Unblock-File` dans le kit, et passe par `installer.cmd` |
| `copilot` introuvable après `npm install` | Ouvre un nouveau terminal |
| `--yolo` ou le mode autopilot refusé | Une stratégie d'organisation s'applique à ton abonnement Copilot : seul son administrateur peut la lever |
| `Model "auto" does not support reasoning effort` | Retire `--reasoning-effort`, ou fixe un modèle avec `install.ps1 -Model <nom>` |
| Un paquet Python est bloqué | Le contrôle intelligent des applications de Windows est en cause. Le moteur de scraping exporte déjà ses fichiers Parquet sans `pandas` ni `duckdb` |
| `jev` répond que la clé manque | Lance `.\mcp-scraping.ps1` et tape ta clé TypeSafe. Sans elle, les agents passent à l'outil suivant |
| Un outil de pentest est supprimé par l'antivirus | Travaille dans WSL, Docker ou une machine virtuelle. Le kit n'ajoute pas d'exclusion |
