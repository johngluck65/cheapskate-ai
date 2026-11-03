#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
require_macos
ensure_brew
ensure_git
ensure_docker

REPO="${LIBRECHAT_DIR:-$HOME/repos/LibreChat}"
URL="http://localhost:3080"

log "LibreChat setup"
if [[ -e "$REPO" ]]; then
  [[ -d "$REPO/.git" ]] || die "$REPO exists but is not a Git checkout. Leaving it untouched."
  log "Existing LibreChat checkout found at $REPO. Not pulling or changing it."
else
  clone_if_missing "https://github.com/LibreChat-AI/LibreChat.git" "$REPO"
fi

cd "$REPO"
if [[ ! -f .env ]]; then
  [[ -f .env.example ]] || die "LibreChat's .env.example file is missing."
  cp .env.example .env
  log "Created .env from .env.example. No provider API keys were added."
else
  log "Existing .env found; leaving it untouched."
fi

if docker ps --format '{{.Names}}' | grep -Fxq "LibreChat"; then
  log "LibreChat container is already running."
elif docker ps -a --format '{{.Names}}' | grep -Fxq "LibreChat"; then
  log "A stopped LibreChat container already exists. Starting it without recreating it."
  docker start LibreChat
else
  log "Starting LibreChat with its upstream Docker Compose configuration"
  docker compose up -d
fi

echo
echo "LibreChat setup finished. Open $URL"
echo "Create your local account, then configure a model provider."
echo "LibreChat does not include model inference; provider usage may cost money."
open_url "$URL"
