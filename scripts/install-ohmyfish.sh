#!/bin/bash

source $HOME/dotfiles/globals.sh

DEST_DIR="$HOME/.local/share/omf"

if [ "$FORCE" = true ]; then
    print_color red "FORCE Enabled: Removing ${DEST_DIR} ..."
    rm -rf $DEST_DIR
fi

