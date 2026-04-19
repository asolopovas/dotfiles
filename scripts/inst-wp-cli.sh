#!/bin/bash
set -euo pipefail
source "$HOME/dotfiles/globals.sh"

DEST="$HOME/.local/bin/wp"

if [ "${FORCE:-false}" != true ] && cmd_exist wp; then
    print_color green "wp-cli already installed — skipping"
    exit 0
fi

print_color green "Installing WP-CLI..."
mkdir -p "$(dirname "$DEST")"
curl -fsSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o "$DEST"
chmod +x "$DEST"
