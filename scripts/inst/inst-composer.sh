#!/bin/bash
set -euo pipefail
source "$HOME/dotfiles/globals.sh"

DEST="$HOME/.local/bin/composer"

if [ "${FORCE:-false}" = true ]; then
    rm -f "$DEST"
fi

if [ -x "$DEST" ] || cmd_exist composer; then
    print_color green "composer already installed — skipping"
    exit 0
fi

print_color green "Installing Composer..."
mkdir -p "$(dirname "$DEST")"
curl -fsSL https://getcomposer.org/download/latest-stable/composer.phar -o "$DEST"
chmod +x "$DEST"
