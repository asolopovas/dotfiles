#!/bin/bash

source $HOME/dotfiles/globals.sh

if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ] || [ "$OS" = "linuxmint" ]; then
    sudo apt-add-repository -y ppa:fish-shell/release-3
    sudo apt update -qq -y
    sudo apt install fish -y
fi

rm -rf $HOME/.config/fish >/dev/null
ln -sf $DOTFILES_DIR/.config/fish $HOME/.config/

