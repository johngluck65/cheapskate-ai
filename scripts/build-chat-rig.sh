#!/usr/bin/env bash
set -euo pipefail
# Backward-compatible name for the original Odysseus bootstrap.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/build-odysseus-rig.sh" "$@"
