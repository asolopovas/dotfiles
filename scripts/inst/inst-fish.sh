#!/bin/bash
set -euo pipefail
source "$HOME/dotfiles/globals.sh"

if [ "${FORCE:-false}" != true ] && cmd_exist fish; then
    print_color green "fish already installed — skipping"
    return 0 2>/dev/null || exit 0
fi

print_color green "Installing fish for $OS..."
case "$OS" in
    ubuntu | debian | linuxmint | pop)
        if sudo apt-add-repository -y ppa:fish-shell/release-3 2>/dev/null \
            && sudo apt update -qq 2>/dev/null; then
            sudo apt install -y fish
        else
            print_color yellow "fish PPA unavailable for this release — using distro repos"
            sudo rm -f /etc/apt/sources.list.d/fish-shell-ubuntu-release-3-*.sources \
                /etc/apt/sources.list.d/fish-shell-ubuntu-release-3-*.list 2>/dev/null || true
            sudo apt update -qq
            sudo apt install -y fish
        fi
        ;;
    fedora) sudo dnf install -y fish ;;
    arch) sudo pacman -S --noconfirm fish ;;
    macos) brew install fish ;;
    *)
        print_color red "Unsupported OS: $OS"
        return 1 2>/dev/null || exit 1
        ;;
esac
