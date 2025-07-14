#!/bin/bash

set -e

# Functions
install_packages() {
    local -A install_cmds=(
        ["debian"]="sudo apt install git libx11-dev libxft-dev libxinerama-dev libxrandr-dev libxss-dev"
        ["fedora"]="sudo dnf install git libX11-devel libXft-devel libXinerama-devel libXrandr-devel libXScrnSaver-devel"
        ["arch"]="sudo pacman -S git xorg-server xorg-apps xorg-xinit xorg-xmessage libx11 libxft libxinerama libxrandr libxss pkgconf"
    )
    ${install_cmds["$1"]}
}
setup_xmonad_log() {
    mkdir -p "$XMONAD_LOG"
    git clone https://github.com/xintron/xmonad-log.git "$XMONAD_LOG"

    pushd "$XMONAD_LOG"
    go mod init
    go get github.com/godbus/dbus
    go build
    mv xintron $GOPATH/bin/xmonad-log
    popd
}

clone_repo_if_not_exists() {
    [ -d "$2" ] || {
        cmd="git clone"
        [ "$3" ] && cmd="$cmd --branch $3"
        $cmd "$1" "$2"
    }
}

# Variables
OS=$(awk -F= '/^ID=/ {gsub(/"/, "", $2); print tolower($2)}' /etc/os-release)
XMONAD_SRC="$HOME/dotfiles/.config/xmonad"
XMONAD_DEST="$HOME/.config/xmonad"
XMONAD_LOG="$GOPATH/src/github.com/xintron"

# Set up Xmonad config
[ ! -d "$XMONAD_DEST" ] && mkdir -p "$XMONAD_DEST"
ln -s "$XMONAD_SRC/xmonad.hs" "$XMONAD_DEST/xmonad.hs" 
cp "$XMONAD_SRC/stack.yaml" "$XMONAD_DEST/stack.yaml" 

# Setup xmonad-log if not exists
[ ! -d $XMONAD_LOG ] && setup_xmonad_log

# Clone repositories if not present
clone_repo_if_not_exists "https://github.com/xmonad/xmonad" "$XMONAD_DEST/xmonad" "v0.17.2"
clone_repo_if_not_exists "https://github.com/xmonad/xmonad-contrib" "$XMONAD_DEST/xmonad-contrib" "v0.17.1"
clone_repo_if_not_exists "https://github.com/troydm/xmonad-dbus.git" "$XMONAD_DEST/xmonad-dbus" ""

# Installing dependencies for different systems
if [ -f /etc/debian_version ] || [ "$OS" == "pop" ] || [ "$OS" == "linuxmint" ]; then
    install_packages "debian"
elif [ -f /etc/fedora-release ]; then
    install_packages "fedora"
elif [ -f /etc/arch-release ]; then
    install_packages "arch"
else
    echo "Unsupported system."
    exit 1
fi

# Install Haskell Stack if not present
command -v stack &>/dev/null || curl -sSL https://get.haskellstack.org/ | sh

pushd "$XMONAD_DEST"

stack install

# Create xmonad.desktop if not exists
if [ ! -f /usr/share/xsessions/xmonad.desktop ]; then
    sudo tee /usr/share/xsessions/xmonad.desktop >/dev/null <<EOT
[Desktop Entry]
Name=Xmonad
Comment=Lightweight Tiling Window Manager
Exec=$HOME/.cache/xmonad/xmonad-x86_64-linux
Type=XSession
DesktopNames=Xmonad
EOT
fi
