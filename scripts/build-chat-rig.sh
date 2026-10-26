#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/odysseus-dev/odysseus.git"
REPO="${ODYSSEUS_DIR:-$HOME/repos/odysseus}"

# Check for macOS
if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "This installer is for macOS only."
    exit 1
fi

# Install Homebrew if necessary
if ! command -v brew >/dev/null 2>&1; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    else
        echo "Homebrew installation could not be located."
        exit 1
    fi
fi

# Install Git if necessary
if ! command -v git >/dev/null 2>&1; then
    echo "Installing Git..."
    brew install git
fi

# Clone Odysseus if it isn't already present
if [[ -d "$REPO" ]]; then
    echo "Odysseus directory already exists at $REPO"
    echo "Leaving the existing directory untouched."
else
    echo "Cloning Odysseus..."
    mkdir -p "$(dirname "$REPO")"
    git clone --branch main "$REPO_URL" "$REPO"
fi

echo
echo "Setup complete."
echo "To start Odysseus, run:"
echo "cd \"$REPO\" && ./start-macos.sh"
