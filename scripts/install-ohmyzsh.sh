#!/bin/bash

DEST_DIR="$HOME/.local/share/ohmyzsh"


if [ "$FORCE" = true ]; then
    print_color red "FORCE Enabled: Removing ${DEST_DIR} ..."
    rm -rf $DEST_DIR
fi

if [ ! -d "$DEST_DIR" ]; then
    print_color green "Installing OhMyZsh for ${OS^} ..."
    ZSH=$DEST_DIR sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    ln -sf $HOME/dotfiles/.config/zsh $HOME/.config/zsh
    ln -sf $HOME/dotfiles/.config/zsh/.zshrc $HOME/.zshrc
fi
