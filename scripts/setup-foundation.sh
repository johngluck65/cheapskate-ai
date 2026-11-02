#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
require_macos

log "Cheapskate AI shared foundation"
ensure_brew
ensure_git

echo
echo "Shared foundation is ready."
echo "No Docker runtime, Ollama, Python, models, or chat application was installed."
echo "Install only the rig(s) you want:"
echo "  scripts/build-odysseus-rig.sh"
echo "  scripts/build-librechat-rig.sh"
echo "  scripts/build-openui-rig.sh"
