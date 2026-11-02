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
  command -v brew >/dev/null 2>&1 || die "Homebrew is required. Install it from https://brew.sh, then rerun this script."
}

ensure_git() {
  if ! command -v git >/dev/null 2>&1; then
    ensure_brew
    log "Installing Git"
    brew install git
  fi
}

ensure_docker() {
  command -v docker >/dev/null 2>&1 || die "Docker CLI not found. Install OrbStack (recommended here) or another Docker-compatible runtime."
  docker info >/dev/null 2>&1 || die "Docker engine is not running. Start OrbStack (or your Docker-compatible runtime), then rerun."
  docker compose version >/dev/null 2>&1 || die "Docker Compose v2 is required."
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
