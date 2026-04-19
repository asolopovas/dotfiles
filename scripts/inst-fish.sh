#!/bin/bash
set -euo pipefail
source "$HOME/dotfiles/globals.sh"

if [ "${FORCE:-false}" != true ] && cmd_exist fish; then
    print_color green "fish already installed — skipping"
    exit 0
fi

print_color green "Installing fish for $OS..."
case "$OS" in
    ubuntu|debian|linuxmint|pop)
        sudo apt-add-repository -y ppa:fish-shell/release-3
        sudo apt update -qq
        sudo apt install -y fish
        ;;
    fedora) sudo dnf install -y fish ;;
    arch)   sudo pacman -S --noconfirm fish ;;
    macos)  brew install fish ;;
    *)
        print_color red "Unsupported OS: $OS"
        exit 1
        ;;
esac
