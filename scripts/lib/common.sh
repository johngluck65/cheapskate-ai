#!/usr/bin/env bash
# Shared helpers for the Cheapskate AI installers.
set -euo pipefail

log()  { printf '\n==> %s\n' "$*"; }
warn() { printf '\nWARNING: %s\n' "$*" >&2; }
die()  { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

require_macos() {
  [[ "$(uname -s)" == "Darwin" ]] || die "These installers currently support macOS only."
}

ensure_brew() {
  command -v brew >/dev/null 2>&1 && return 0

  echo "Homebrew not found. Installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
    || die "Homebrew installation failed."

  # The installer doesn't add brew to PATH in the current shell
  local candidate
  for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
    if [ -x "$candidate" ]; then
      eval "$("$candidate" shellenv)"
      break
    fi
  done

  command -v brew >/dev/null 2>&1 \
    || die "Homebrew installed but not on PATH. Open a new terminal and rerun."
}

ensure_git() {
  if ! command -v git >/dev/null 2>&1; then
    ensure_brew
    log "Installing Git"
    brew install git
  fi
}
ensure_orbstack() {
  # Any working Docker daemon is enough; don't install over an existing runtime.
  docker_ready() { command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; }

  # OrbStack puts its docker CLI here; it may not be on PATH yet in this shell.
  export PATH="$HOME/.orbstack/bin:$PATH"

  docker_ready && return 0

  if [ -d /Applications/Docker.app ]; then
    die "Docker Desktop is installed but not running. Start it and rerun, or remove it to use OrbStack."
  fi

  if [ ! -d /Applications/OrbStack.app ]; then
    ensure_brew
    log "Installing OrbStack"
    brew install --cask orbstack
  fi

  log "Starting OrbStack (first launch may ask for permissions in the app window)"
  open -a OrbStack

  local i
  for i in $(seq 1 90); do
    docker_ready && return 0
    sleep 2
  done

  die "OrbStack did not become ready within 3 minutes. Open it, finish any setup prompts, and rerun."
}

ensure_docker() {
  ensure_orbstack
  docker compose version >/dev/null 2>&1 \
    || die "Docker Compose v2 is required. Update OrbStack, or your Docker runtime if you use another."
}

clone_if_missing() {
  local url="$1" dest="$2" branch_name="${3:-}"
  if [[ -e "$dest" ]]; then
    [[ -d "$dest/.git" ]] || die "$dest already exists but is not a Git repository. Leaving it untouched."
    log "Found existing checkout at $dest; leaving it untouched."
   return 0
  fi
  mkdir -p "$(dirname "$dest")"
  if [[ -n "$branch_name" ]]; then
    git clone --branch "$branch_name" "$url" "$dest"
  else
    git clone "$url" "$dest"
  fi
}

open_url() {
  local url="$1"
  if command -v open >/dev/null 2>&1; then open "$url"; else printf 'Open this URL: %s\n' "$url"; fi
}
