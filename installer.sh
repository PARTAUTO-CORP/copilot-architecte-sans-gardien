#!/usr/bin/env bash
# Linux counterpart of installer.cmd. Two parts:
#  1. System, needs root or sudo: Google Chrome, Python venv, ICU for PowerShell. Skipped with a warning without root.
#  2. This account, no root: PowerShell 7, Node 24 and Copilot CLI in ~/.local, a standalone Python 3.12 (uv)
#     when the distribution's is too old, then bootstrap.ps1, which installs the kit and checks it.
# Usage: bash installer.sh [-NoPrompt] [-Reset] [-Model <name>] [-Effort <level>]  (same options as installer.cmd)
#        bash installer.sh -SystemOnly   as root: part 1 only, before installing the kit for a dedicated user
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"

fail() { echo "[KO] $*" >&2; exit 1; }
warn() { echo "[!!] $*" >&2; }
[ "$(uname -s)" = Linux ] || fail "installer.sh is for Linux. On Windows, run installer.cmd."

case "$(uname -m)" in
  x86_64) arch=x64 ;;
  aarch64 | arm64) arch=arm64 ;;
  *) fail "Unsupported processor: $(uname -m)" ;;
esac

no_prompt=0
system_only=0
for option in "$@"; do
  if [ "$option" = -NoPrompt ]; then no_prompt=1; fi
  if [ "$option" = -SystemOnly ]; then system_only=1; fi
done

bin="$HOME/.local/bin"
opt="$HOME/.local/opt"
case ":$PATH:" in *":$bin:"*) path_had_bin=1 ;; *) path_had_bin=0 ;; esac
export PATH="$bin:$PATH"

# Root access: root itself, passwordless sudo, or sudo with a password typed by a person.
# With -NoPrompt (an AI installing) sudo never waits for a password: the step is skipped with a warning.
if [ "$(id -u)" -eq 0 ]; then root_cmd=""
elif command -v sudo >/dev/null && sudo -n true 2>/dev/null; then root_cmd="sudo"
elif command -v sudo >/dev/null && [ -t 0 ] && [ "$no_prompt" = 0 ]; then root_cmd="sudo"
else root_cmd="none"
fi
# noninteractive and NEEDRESTART_MODE: apt must never stop on a question (tzdata, needrestart).
as_root() {
  case "$root_cmd" in
    none) return 1 ;;
    "") env DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a "$@" ;;
    *) sudo env DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a "$@" ;;
  esac
}

# Lock timeout: on a fresh Ubuntu VPS, unattended-upgrades holds the dpkg lock for the first minutes.
apt_updated=0
apt_install() {
  if [ "$apt_updated" = 0 ]; then as_root apt-get -o DPkg::Lock::Timeout=600 update -qq; apt_updated=1; fi
  as_root apt-get -o DPkg::Lock::Timeout=600 install -y -qq "$@"
}
# $1 apt packages, $2 dnf/zypper packages, $3 pacman packages
system_install() {
  [ "$root_cmd" != none ] || return 1
  if command -v apt-get >/dev/null; then apt_install $1
  elif command -v dnf >/dev/null; then as_root dnf install -y $2
  elif command -v zypper >/dev/null; then as_root zypper --non-interactive install $2
  elif command -v pacman >/dev/null; then as_root pacman -S --needed --noconfirm $3
  else return 1
  fi
}

# version_at_least 3.12.4 3.12
version_at_least() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]; }
version_of() { "$@" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1 || true; }
# Latest release tag of a GitHub repo, read from the redirect: no API call, no rate limit.
latest_tag() { curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$1/releases/latest" | sed 's#.*/tag/v##'; }

# Same test as install.ps1: a real venv from the real interpreter, not from a symlink.
python_ok() {
  command -v python3 >/dev/null || return 1
  version_at_least "$(version_of python3 --version)" 3.12 || return 1
  local real tmp ok
  real="$(python3 -c 'import os, sys; print(os.path.realpath(sys.executable))')" || return 1
  tmp="$(mktemp -d)"
  "$real" -m venv "$tmp/v" >/dev/null 2>&1 && ok=0 || ok=1
  rm -rf "$tmp"
  return $ok
}
icu_ok() { compgen -G '/usr/lib*/libicuuc.so*' >/dev/null || compgen -G '/usr/lib*/*/libicuuc.so*' >/dev/null; }
# The playwright MCP server opens /opt/google/chrome/chrome, and the Jev browser finds it too.
chrome_ok() { [ -x /opt/google/chrome/chrome ]; }

downloaders_ok() { command -v curl >/dev/null && command -v tar >/dev/null && command -v xz >/dev/null; }
downloaders_ok || system_install "curl tar xz-utils ca-certificates" "curl tar xz" "curl tar xz" || true
downloaders_ok || fail "curl, tar and xz are missing. Install them as root, then run this again."

# ---------- 1. System (root) ----------
if [ "$root_cmd" = none ]; then
  [ "$system_only" = 0 ] || fail "-SystemOnly needs root: run it as root or with sudo."
  if ! icu_ok || { ! chrome_ok && [ "$arch" = x64 ]; }; then
    warn "No root access without a password: missing system packages (Chrome, ICU) cannot be installed. Run 'bash installer.sh' yourself in a terminal (it asks for your sudo password), or 'bash installer.sh -SystemOnly' as root."
  fi
else
  if ! python_ok; then
    echo "Installing Python 3 from the distribution..."
    # No python3-pip: venv brings its own pip, and on Debian the package pulls a compiler (hundreds of MB).
    system_install "python3 python3-venv" "python3" "python" || true
  fi
  if ! icu_ok; then
    echo "Installing ICU, needed by PowerShell..."
    system_install "libicu-dev" "libicu" "icu" || true
  fi
  # Google builds Chrome for x64 only. Its package pulls the system libraries a browser needs.
  if ! chrome_ok && [ "$arch" = x64 ]; then
    echo "Installing Google Chrome..."
    if command -v apt-get >/dev/null; then
      tmp="$(mktemp -d)"
      curl -fsSL -o "$tmp/google-chrome.deb" https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
      apt_install "$tmp/google-chrome.deb" || true
      rm -rf "$tmp"
    elif command -v dnf >/dev/null; then
      as_root dnf install -y https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm || true
    fi
  fi
fi
if chrome_ok; then echo "[OK] Google Chrome"
else warn "Google Chrome is not installed: the playwright MCP server and the Jev browser cannot open pages. x64 only; on arm64 the other scraping tools still work."
fi

if [ "$system_only" = 1 ]; then
  echo "System part done. Now install the kit as the user who will run Copilot: bash installer.sh"
  exit 0
fi
if [ "$(id -u)" -eq 0 ]; then
  warn "Installing the kit for root: cop will have full control of this server, and the Jev browser cannot start Chrome as root. A dedicated user is safer: see 'Installer sur un VPS' in README.md."
fi

# ---------- 2. This account (no root) ----------
mkdir -p "$bin" "$opt"

if ! python_ok; then
  # Ubuntu 22.04, Debian 12 and older, or no root: a standalone Python 3.12 from uv, linked as ~/.local/bin/python3.
  echo "Installing a standalone Python 3.12 with uv in ~/.local..."
  command -v uv >/dev/null || curl -fsSL https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="$bin" UV_NO_MODIFY_PATH=1 sh
  uv python install 3.12
  ln -sf "$(UV_PYTHON_PREFERENCE=only-managed uv python find 3.12)" "$bin/python3"
  hash -r
  python_ok || fail "Python 3.12 or newer with venv is still missing. Install it by hand, then run this again."
fi
echo "[OK] Python $(version_of python3 --version)"

# PowerShell 7: official archive.
pwsh_ok() { command -v pwsh >/dev/null && version_at_least "$(version_of pwsh --version)" 7.3; }
if ! pwsh_ok; then
  tag="$(latest_tag PowerShell/PowerShell)"
  echo "Installing PowerShell $tag in $opt/powershell..."
  rm -rf "$opt/powershell" && mkdir -p "$opt/powershell"
  curl -fsSL "https://github.com/PowerShell/PowerShell/releases/download/v$tag/powershell-$tag-linux-$arch.tar.gz" | tar -xz -C "$opt/powershell"
  chmod +x "$opt/powershell/pwsh"
  ln -sf "$opt/powershell/pwsh" "$bin/pwsh"
  hash -r
fi
pwsh -NoProfile -Command 'exit 0' >/dev/null 2>&1 \
  || fail "PowerShell 7 does not start: the ICU library is probably missing. As root: bash installer.sh -SystemOnly, then run this again."
pwsh_ok || fail "PowerShell 7.3 or newer is still missing."
echo "[OK] PowerShell $(version_of pwsh --version)"

# Node 24: official archive, distributions often ship an older one.
node_ok() { command -v node >/dev/null && version_at_least "$(version_of node --version)" 24.0; }
if ! node_ok; then
  file="$(curl -fsSL https://nodejs.org/dist/latest-v24.x/SHASUMS256.txt | grep -oE "node-v[0-9.]+-linux-$arch\.tar\.xz" | head -n1)"
  [ -n "$file" ] || fail "Could not find Node 24 for linux-$arch on nodejs.org."
  echo "Installing ${file%.tar.xz} in $opt/node..."
  rm -rf "$opt/node" && mkdir -p "$opt/node"
  curl -fsSL "https://nodejs.org/dist/latest-v24.x/$file" | tar -xJ -C "$opt/node" --strip-components=1
  for tool in node npm npx; do ln -sf "$opt/node/bin/$tool" "$bin/$tool"; done
  hash -r
fi
node_ok || fail "Node.js 24 or newer is still missing."
echo "[OK] Node.js $(version_of node --version)"

# --prefix ~/.local: no root, and the command lands in ~/.local/bin like the others.
if ! command -v copilot >/dev/null; then
  echo "Installing GitHub Copilot CLI..."
  npm install -g --prefix "$HOME/.local" @github/copilot
  hash -r
  command -v copilot >/dev/null || fail "GitHub Copilot CLI could not be installed: run npm install -g --prefix ~/.local @github/copilot"
fi
echo "[OK] GitHub Copilot CLI"

# New terminals must find pwsh, node, python3 and copilot too.
if [ "$path_had_bin" = 0 ]; then
  for rc in "$HOME/.profile" "$HOME/.bashrc" "$HOME/.zshrc"; do
    [ -f "$rc" ] || [ "$rc" = "$HOME/.profile" ] || continue
    grep -qs 'copilot-architecte: ~/.local/bin' "$rc" && continue
    printf '\nexport PATH="$HOME/.local/bin:$PATH"  # copilot-architecte: ~/.local/bin\n' >> "$rc"
  done
  echo "[OK] ~/.local/bin added to PATH for new terminals"
fi

exec pwsh -NoProfile -File "$here/bootstrap.ps1" "$@"
