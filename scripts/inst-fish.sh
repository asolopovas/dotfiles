#!/bin/bash

source "$HOME/dotfiles/globals.sh"

if [ "${FORCE:-false}" != true ] && command -v fish &>/dev/null; then
    print_color green "fish already installed — skipping"
    return 0 2>/dev/null || exit 0
fi

case $OS in
    ubuntu|debian|linuxmint|pop)
        sudo apt-add-repository -y ppa:fish-shell/release-3
        sudo apt update -qq -y
        sudo apt install fish -y
        ;;
    fedora)
        sudo dnf install -y fish
        ;;
    arch)
        sudo pacman -S --noconfirm fish
        ;;
    macos)
        brew install fish
        ;;
    *)
        print_color red "Unsupported OS for fish install: $OS"
        ;;
esac
