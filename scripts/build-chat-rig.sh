#!/usr/bin/env bash
#
# build-chat-rig.sh
#
# Conservative preflight check for:
#   macOS
#   OrbStack or Docker
#   Ollama
#   Open WebUI
#   OpenRouter
#
# This script does not:
#   - Install software
#   - Pull models
#   - Restart containers
#   - Delete anything
#   - Modify Docker volumes
#   - Store an API key
#

set -uo pipefail

MODE="check"
OPENROUTER_KEY="${OPENROUTER_API_KEY:-}"

usage() {
  cat <<'EOF'
Usage:
  build-chat-rig.sh --check-only
  build-chat-rig.sh --help

This script only checks the local chat rig. It does not install software,
pull models, modify Docker volumes, restart containers, or store an API key.
EOF
}

while (($#)); do
  case "$1" in
    --check-only)
      MODE="check"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

pass() {
  printf 'PASS: %s\n' "$*"
}

warn() {
  printf 'WARN: %s\n' "$*"
}

fail() {
  printf 'FAIL: %s\n' "$*"
}

DOCKER_CMD=""
ORB_CMD=""

DOCKER_OK=0
ORB_OK=0

DOCKER_INFO=""
ORB_STATUS=""
CONTEXT=""
CONTEXT_INFO=""

RUNTIME="none"

OLLAMA_OK=0
MODEL_OK=0
WEBUI_OK=0
OR_AUTH_OK=0

FATAL=0

# -----------------------------------------------------------------------------
# 1. Detect the Docker-compatible runtime first.
# -----------------------------------------------------------------------------

if command -v docker >/dev/null 2>&1; then
  DOCKER_CMD="$(command -v docker)"

  if DOCKER_INFO="$(docker info 2>&1)"; then
    DOCKER_OK=1
  else
    warn "Docker-compatible API is not reachable"
  fi
else
  warn "docker command not found"
fi

# OrbStack normally provides an `orb` CLI.
# Running `orb status` is read-only.
if command -v orb >/dev/null 2>&1; then
  ORB_CMD="$(command -v orb)"

  if ORB_STATUS="$(orb status 2>&1)"; then
    ORB_OK=1
  else
    warn "orb command is installed, but orb status did not succeed"
  fi
else
  warn "orb command not found"
fi

if ((DOCKER_OK)); then
  CONTEXT="$($DOCKER_CMD context show 2>/dev/null || true)"
  CONTEXT_INFO="$($DOCKER_CMD context inspect "$CONTEXT" 2>/dev/null || true)"

  # OrbStack commonly uses an "orbstack" Docker context.
  if [[ "$CONTEXT" == *"orbstack"* ]] ||
     grep -qi 'orbstack' <<<"$CONTEXT_INFO" ||
     grep -qi 'orbstack' <<<"$DOCKER_INFO"; then
    RUNTIME="orbstack"

  # Docker Desktop commonly uses "desktop".
  elif [[ "$CONTEXT" == *"docker-desktop"* ]] ||
       [[ "$CONTEXT" == "desktop" ]] ||
       grep -qi 'docker desktop' <<<"$CONTEXT_INFO"; then
    RUNTIME="docker"

  # Both may be installed. If the active context is ambiguous, do not guess.
  elif ((ORB_OK)); then
    RUNTIME="docker-compatible (OrbStack CLI installed; active context not identified as OrbStack)"
  else
    RUNTIME="docker-compatible"
  fi
elif ((ORB_OK)); then
  RUNTIME="orbstack (CLI healthy; Docker API unavailable)"
fi

if ((DOCKER_OK)); then
  pass "Docker-compatible engine is reachable"
else
  warn "No reachable Docker-compatible engine"
fi

if ((ORB_OK)); then
  pass "OrbStack CLI status check succeeded"
fi

case "$RUNTIME" in
  none)
    fail "No container runtime detected"
    FATAL=1
    ;;
  *)
    pass "Detected runtime: $RUNTIME"
    ;;
esac

# -----------------------------------------------------------------------------
# 2. Find an existing Open WebUI container, if Docker is available.
# -----------------------------------------------------------------------------

if ((DOCKER_OK)); then
  CONTAINERS="$($DOCKER_CMD ps -a --format '{{.Names}} {{.Status}}' |
    grep -Ei 'open[-_ ]?webui' || true)"

  if [[ -n "$CONTAINERS" ]]; then
    pass "Existing Open WebUI container found:"
    printf '%s\n' "$CONTAINERS"
  else
    warn "No Open WebUI-named container found"
  fi
fi

# -----------------------------------------------------------------------------
# 3. Check Ollama.
# -----------------------------------------------------------------------------

if ! command -v ollama >/dev/null 2>&1; then
  fail "ollama command not found"
else
  if curl -fsS \
    --connect-timeout 2 \
    --max-time 3 \
    http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    pass "Ollama API is responding"
    OLLAMA_OK=1
  else
    fail "Ollama is installed, but its API is not responding on port 11434"
  fi
fi

# -----------------------------------------------------------------------------
# 4. Check for qwen3:8b.
# -----------------------------------------------------------------------------

if ((OLLAMA_OK)); then
  if ollama list 2>/dev/null | awk '$1 ~ /^qwen3:8b($|-)/ {found=1} END {exit !found}'; then
    pass "qwen3:8b is installed"
    MODEL_OK=1
  else
    fail "qwen3:8b is not installed"
  fi
fi

# -----------------------------------------------------------------------------
# 5. Check Open WebUI.
# -----------------------------------------------------------------------------

if curl -fsSL \
  --connect-timeout 2 \
  --max-time 5 \
  http://127.0.0.1:3000/ >/dev/null 2>&1; then
  pass "Open WebUI is responding at http://localhost:3000"
  WEBUI_OK=1
else
  fail "Open WebUI is not responding at http://localhost:3000"
fi

# -----------------------------------------------------------------------------
# 6. Optionally validate the OpenRouter key.
#
# The key must be supplied through OPENROUTER_API_KEY. It is never written to
# the script and is not printed by this script.
# -----------------------------------------------------------------------------

if [[ -z "$OPENROUTER_KEY" ]]; then
  warn "OPENROUTER_API_KEY is not set; skipping OpenRouter authentication test"
else
  if HTTP_CODE="$(curl -sS \
    --connect-timeout 5 \
    --max-time 15 \
    -o /dev/null \
    -w '%{http_code}' \
    -H "Authorization: Bearer $OPENROUTER_KEY" \
    https://openrouter.ai/api/v1/models 2>/dev/null)"; then

    if [[ "$HTTP_CODE" == "200" ]]; then
      pass "OpenRouter API authentication succeeded"
      OR_AUTH_OK=1
    elif [[ "$HTTP_CODE" == "401" || "$HTTP_CODE" == "403" ]]; then
      fail "OpenRouter rejected the API key"
    else
      warn "OpenRouter API returned HTTP $HTTP_CODE"
    fi
  else
    fail "Could not reach the OpenRouter API"
  fi
fi

# -----------------------------------------------------------------------------
# 7. Summary and exit status.
# -----------------------------------------------------------------------------

if ((DOCKER_OK == 0)); then
  fail "No reachable Docker-compatible API"
  FATAL=1
fi

if ((OLLAMA_OK == 0)); then
  FATAL=1
fi

if ((MODEL_OK == 0)); then
  FATAL=1
fi

if ((WEBUI_OK == 0)); then
  FATAL=1
fi

if [[ -n "$OPENROUTER_KEY" && "$OR_AUTH_OK" -eq 0 ]]; then
  FATAL=1
fi

if ((FATAL)); then
  printf '\nPreflight failed. No changes were made.\n'
  exit 1
fi

printf '\nPreflight passed. No changes were made.\n'
exit 0
