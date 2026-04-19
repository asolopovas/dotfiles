#!/bin/bash
set -euo pipefail
source "$HOME/dotfiles/globals.sh"

VER="$(gh_latest_release tmux/tmux)"
URL="https://github.com/tmux/tmux/releases/download/${VER}/tmux-${VER}.tar.gz"

if cmd_exist tmux; then
    installed="$(tmux -V | grep -oE '[0-9]+\.[0-9]+[a-z]?' || true)"
    if [[ "$installed" == "$VER" ]]; then
        print_color green "tmux $VER already installed"
        exit 0
    fi
    print_color yellow "tmux $installed found, upgrading to $VER..."
fi

print_color green "Installing tmux $VER from source..."

case $OS in
    ubuntu | debian | linuxmint)
        sudo apt-get update -qq
        sudo apt-get install -y build-essential libevent-dev libncurses-dev bison pkg-config
        ;;
    centos | fedora)
        sudo dnf groupinstall -y "Development Tools"
        sudo dnf install -y libevent-devel ncurses-devel bison pkgconf-pkg-config
        ;;
    arch)
        sudo pacman -S --needed --noconfirm base-devel libevent ncurses bison pkgconf
        ;;
esac

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
curl -fsSL "$URL" | tar xz -C "$TMP"
make -C "$TMP/tmux-$VER" -j"$(nproc)"
sudo make -C "$TMP/tmux-$VER" install

if cmd_exist tmux && [[ "$(tmux -V)" == *"$VER"* ]]; then
    print_color green "tmux $VER installed successfully at $(command -v tmux)"
else
    print_color red "tmux installation failed"
    exit 1
fi
