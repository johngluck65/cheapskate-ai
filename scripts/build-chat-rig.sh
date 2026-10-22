#!/usr/bin/env bash
set -euo pipefail

# AI Chat Rig bootstrap for macOS
#
# Target architecture:
#   Ollama -> Qwen3 8B (local)
#   Open WebUI -> Ollama + OpenRouter
#   OpenRouter -> openrouter/free
#
# This script is intentionally conservative:
# - It does not delete/recreate an existing Open WebUI container.
# - It does not store your OpenRouter API key in this file.
# - It can be rerun safely.
#
# IMPORTANT:
# Open WebUI's admin connection settings are application data, and the exact
# REST/admin API for modifying them can vary by Open WebUI version. Therefore
# this script prepares and verifies the local stack, then prints the exact
# OpenRouter values to enter if the connection is not already configured.
#
# Usage:
#   chmod +x build-chat-rig.sh
#   ./build-chat-rig.sh
#
# Optional:
#   OPENROUTER_API_KEY='...' ./build-chat-rig.sh
#
# The key is NEVER printed.

OPEN_WEBUI_URL="${OPEN_WEBUI_URL:-http://localhost:3000}"
OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"
OLLAMA_MODEL="${OLLAMA_MODEL:-qwen3:8b}"
OPENROUTER_BASE_URL="${OPENROUTER_BASE_URL:-https://openrouter.ai/api/v1}"
OPENROUTER_MODEL="${OPENROUTER_MODEL:-openrouter/free}"

log()  { printf '\n==> %s\n' "$1"; }
warn() { printf '\nWARNING: %s\n' "$1" >&2; }
die()  { printf '\nERROR: %s\n' "$1" >&2; exit 1; }

command -v curl >/dev/null 2>&1 || die "curl is required."
command -v docker >/dev/null 2>&1 || die "Docker CLI is not installed/in PATH. Start OrbStack or Docker Desktop first."

log "Checking Docker/OrbStack"
docker info >/dev/null 2>&1 || die "Docker is not running. Start OrbStack (or Docker Desktop), then rerun this script."

log "Checking Ollama"
if ! command -v ollama >/dev/null 2>&1; then
  warn "Ollama is not installed."
  if command -v brew >/dev/null 2>&1; then
    read -r -p "Install Ollama with Homebrew now? [Y/n] " answer
    answer="${answer:-Y}"
    if [[ "$answer" =~ ^[Yy]$ ]]; then
      brew install --cask ollama
    else
      die "Ollama is required for the local Qwen3 8B side of the rig."
    fi
  else
    die "Homebrew is not installed, so the script cannot install Ollama automatically."
  fi
fi

if ! curl -fsS "$OLLAMA_URL/api/tags" >/dev/null 2>&1; then
  warn "Ollama is installed but its server is not responding at $OLLAMA_URL."
  warn "Start the Ollama app, then rerun this script."
  exit 1
fi

log "Checking local model: $OLLAMA_MODEL"
if ! ollama list | awk 'NR>1 {print $1}' | grep -Fxq "$OLLAMA_MODEL"; then
  echo "Model $OLLAMA_MODEL is not installed. Pulling it..."
  ollama pull "$OLLAMA_MODEL"
else
  echo "$OLLAMA_MODEL is already installed."
fi

log "Testing local Ollama model"
if curl -fsS "$OLLAMA_URL/api/tags" | grep -q '"name":"'"${OLLAMA_MODEL//:/\\:}"'"'; then
  echo "Ollama reports $OLLAMA_MODEL."
else
  echo "Ollama is responding; verify the model with: ollama list"
fi

log "Checking Open WebUI"
if curl -fsS "$OPEN_WEBUI_URL" >/dev/null 2>&1; then
  echo "Open WebUI is responding at $OPEN_WEBUI_URL."
else
  warn "Open WebUI is not responding at $OPEN_WEBUI_URL."
  echo
  echo "Running containers:"
  docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}'
  echo
  warn "Start your existing Open WebUI container and rerun this script."
  exit 1
fi

log "Checking OpenRouter"
if [[ -n "${OPENROUTER_API_KEY:-}" ]]; then
  echo "An OpenRouter key was supplied through OPENROUTER_API_KEY."
  echo "Testing the key without printing it..."
  status="$(
    curl -sS -o /tmp/openrouter_models_$$.json -w '%{http_code}' \
      -H "Authorization: Bearer $OPENROUTER_API_KEY" \
      "$OPENROUTER_BASE_URL/models" || true
  )"
  if [[ "$status" == "200" ]]; then
    echo "OpenRouter API key works."
  else
    rm -f /tmp/openrouter_models_$$.json
    warn "OpenRouter returned HTTP $status."
    warn "Check the key in 1Password/OpenRouter and try again."
  fi
  rm -f /tmp/openrouter_models_$$.json
else
  echo "No OpenRouter key supplied."
  echo "That is intentional: the script will not store or prompt-and-save your secret."
fi

cat <<EOF

============================================================
CHAT RIG CHECK
============================================================

Local provider
  Ollama:       $OLLAMA_URL
  Model:        $OLLAMA_MODEL

Open WebUI
  URL:          $OPEN_WEBUI_URL

OpenRouter
  Base URL:     $OPENROUTER_BASE_URL
  Free router:  $OPENROUTER_MODEL

============================================================
OPEN WEBUI CONFIGURATION
============================================================

Your Open WebUI instance is already running, so this script does
NOT replace/recreate it.

In Open WebUI, use:

  Admin Settings -> Connections -> OpenAI API

OpenRouter Base URL:
  $OPENROUTER_BASE_URL

API Key:
  paste your OpenRouter key from 1Password

Model:
  $OPENROUTER_MODEL

Keep the OpenRouter connection restricted to:
  $OPENROUTER_MODEL

Then your model selector should contain:

  $OLLAMA_MODEL       (local, free)
  $OPENROUTER_MODEL   (cloud free-model router)

============================================================
DONE
============================================================

No API key was written to this script.
No existing Open WebUI container was deleted or recreated.

EOF
