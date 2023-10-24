#!/bin/bash

source $HOME/dotfiles/globals.sh

DEST_DIR="$HOME/.local/share/omf"

if [ "$FORCE" = true ]; then
    print_color red "FORCE Enabled: Removing ${DEST_DIR} ..."
    rm -rf $DEST_DIR
fi

if [ ! -d "$HOME/.local/share/omf" ]; then
    print_color green "Installing OhMyFish for ${OS^} ..."
    curl -sO https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install
    fish install --noninteractive --path=$DEST_DIR --config=~/.config/omf
    fish -c "omf install bass"
    rm -f install
fi
