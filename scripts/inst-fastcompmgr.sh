#!/bin/bash
set -euo pipefail
source "$HOME/dotfiles/globals.sh"

SRC="$HOME/src/fastcompmgr"

if [ "${FORCE:-false}" != true ] && cmd_exist fastcompmgr; then
    print_color green "fastcompmgr already installed — skipping"
    exit 0
fi

print_color green "Installing fastcompmgr build deps..."
sudo apt-get update -qq
sudo apt-get install -y \
    libx11-dev libxcomposite-dev libxdamage-dev libxfixes-dev libxrender-dev \
    pkg-config make build-essential git

mkdir -p "$HOME/src"
if [ -d "$SRC" ]; then
    print_color yellow "Updating $SRC"
    git -C "$SRC" pull --ff-only
    make -C "$SRC" clean
else
    git clone https://github.com/tycho-kirchner/fastcompmgr.git "$SRC"
fi

print_color green "Building fastcompmgr..."
make -C "$SRC" -j"$(nproc)"
sudo make -C "$SRC" install

cmd_exist fastcompmgr && print_color green "fastcompmgr installed at $(command -v fastcompmgr)"
