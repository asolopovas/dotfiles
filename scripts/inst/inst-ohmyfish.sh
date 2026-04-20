#!/bin/bash
set -euo pipefail
source "$HOME/dotfiles/globals.sh"

DEST="$HOME/.local/share/omf"

if [ "${FORCE:-false}" = true ]; then
    print_color yellow "FORCE: removing $DEST"
    rm -rf "$DEST"
fi

if [ -d "$DEST" ]; then
    print_color green "oh-my-fish already installed — skipping"
    exit 0
fi

require_cmd fish scripts/inst/inst-fish.sh || exit 1

print_color green "Installing oh-my-fish to $DEST..."
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
curl -fsSL https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install -o "$TMP/install"
fish "$TMP/install" --noninteractive --path="$DEST" --config="$HOME/.config/omf"
fish -c "omf install bass"
