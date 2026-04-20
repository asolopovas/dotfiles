#!/bin/bash
set -euo pipefail
source "$HOME/dotfiles/globals.sh"

DEST="$HOME/.local/share/ohmybash"

if [ "${FORCE:-false}" = true ]; then
    print_color yellow "FORCE: removing $DEST"
    rm -rf "$DEST"
fi

if [ -d "$DEST" ]; then
    print_color green "oh-my-bash already installed — skipping"
    exit 0
fi

print_color green "Installing oh-my-bash..."
git clone https://github.com/ohmybash/oh-my-bash.git "$DEST"
