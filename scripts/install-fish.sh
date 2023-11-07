#!/bin/bash

source "$HOME/dotfiles/globals.sh"

configure_fish() {
    rm -rf "$HOME/.config/fish"
    ln -sf "$DOTFILES_DIR/.config/fish" "$HOME/.config/"
}

case $OS in
ubuntu | debian | linuxmint | pop)
    sudo apt-add-repository -y ppa:fish-shell/release-3
    sudo apt update -qq -y
    sudo apt install fish -y
    ;;
alpine)
    configure_fish
    ;;
esac

if [ "$FORCE" = true ]; then
    configure_fish
fi
