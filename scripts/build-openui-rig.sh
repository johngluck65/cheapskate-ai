#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/setup-foundation.sh"
source "$SCRIPT_DIR/lib/common.sh"
ensure_docker

NAME="open-webui"
IMAGE="${OPEN_WEBUI_IMAGE:-ghcr.io/open-webui/open-webui:main}"
PORT="${OPEN_WEBUI_PORT:-3000}"
URL="http://localhost:$PORT"

log "Open WebUI setup"
if docker ps --format '{{.Names}}' | grep -Fxq "$NAME"; then
  log "Open WebUI container is already running. Leaving it unchanged."
elif docker ps -a --format '{{.Names}}' | grep -Fxq "$NAME"; then
  log "An existing Open WebUI container is stopped. Starting it without recreating it."
  docker start "$NAME"
else
  if docker volume inspect open-webui >/dev/null 2>&1; then
    log "Found existing open-webui data volume; it will be reused."
  else
    log "Creating persistent open-webui data volume"
    docker volume create open-webui >/dev/null
  fi
  SECRET="$(openssl rand -hex 32)"
  log "Downloading and starting Open WebUI"
  docker run -d \
    --name "$NAME" \
    --restart unless-stopped \
    -p "$PORT:8080" \
    --add-host=host.docker.internal:host-gateway \
    -v open-webui:/app/backend/data \
    -e WEBUI_SECRET_KEY="$SECRET" \
    "$IMAGE"
fi

echo
echo "Open WebUI is available at $URL"
echo "The persistent open-webui volume holds its users, chats, and settings."
echo "This installer does not install Ollama or download a model."
echo "To use local models, install Ollama separately and connect it from Open WebUI."
open_url "$URL"
