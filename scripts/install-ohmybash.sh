#!/bin/bash

DEST_DIR="$HOME/.local/share/ohmybash"

source $HOME/dotfiles/globals.sh

print_color green "Installing OhMyBash for ${OS^} ..."

if [ "$FORCE" = true ]; then
    print_color red "FORCE Enabled: Removing ${DEST_DIR} ..."
    rm -rf "$DEST_DIR"
fi

if [ ! -d "$DEST_DIR" ]; then
    git clone https://github.com/ohmybash/oh-my-bash.git $DEST_DIR
fi
