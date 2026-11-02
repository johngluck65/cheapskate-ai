#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
require_macos
ensure_brew
ensure_git

REPO="${ODYSSEUS_DIR:-$HOME/repos/odysseus}"
REPO_URL="https://github.com/odysseus-dev/odysseus.git"

log "Odysseus native macOS setup"
if [[ -e "$REPO" ]]; then
  [[ -d "$REPO/.git" ]] || die "$REPO exists but is not a Git checkout. Leaving it untouched."
  log "Existing Odysseus checkout found at $REPO. Not pulling or changing it."
else
  clone_if_missing "$REPO_URL" "$REPO" main
fi

[[ -x "$REPO/start-macos.sh" ]] || die "start-macos.sh is missing or not executable in $REPO."
echo
echo "Odysseus is ready to launch."
echo "Run:"
printf '  cd "%s" && ./start-macos.sh\n' "$REPO"
echo
echo "On Apple Silicon, the native launcher is the recommended route because Docker on macOS cannot provide Metal GPU access."
