#!/bin/bash

XMONAD_ORIGIN="$HOME/dotfiles/.config/xmonad"
XMONAD_DEST="$HOME/.config/xmonad"
XMONAD_LOG="$GOPATH/src/github.com/xintron"

# Installing dependencies for different systems
if [ -f /etc/debian_version ]; then
    sudo apt install git libx11-dev libxft-dev libxinerama-dev libxrandr-dev libxss-dev
elif [ -f /etc/fedora-release ]; then
    sudo dnf install git libX11-devel libXft-devel libXinerama-devel libXrandr-devel libXScrnSaver-devel
elif [ -f /etc/arch-release ]; then
    sudo pacman -S git xorg-server xorg-apps xorg-xinit xorg-xmessage libx11 libxft libxinerama libxrandr libxss pkgconf
else
    echo "Unsupported system."
    exit 1
fi

command -v stack &>/dev/null || curl -sSL https://get.haskellstack.org/ | sh

[ ! -d $XMONAD_DEST ] && mkdir -p $XMONAD_DEST

ln -sf "$XMONAD_ORIGIN/xmonad.hs" "$XMONAD_DEST/xmonad.hs" >/dev/null 2>&1
ln -sf "$XMONAD_ORIGIN/stack.yaml" "$XMONAD_DEST/stack.yaml" >/dev/null 2>&1

if [ ! -d $XMONAD_LOG ]; then
    mkdir -p $XMONAD_LOG
    git clone https://github.com/xintron/xmonad-log.git $XMONAD_LOG
    go get github.com/godbus/dbus
    go mod init
    go build
    go install
fi

[ ! -d $XMONAD_DEST/xmonad ] && git clone --branch v0.17.2 https://github.com/xmonad/xmonad $XMONAD_DEST/xmonad
[ ! -d $XMONAD_DEST/xmonad-contrib ] && git clone --branch v0.17.1 https://github.com/xmonad/xmonad-contrib $XMONAD_DEST/xmonad-contrib
[ ! -d $XMONAD_DEST/xmonad-dbus ] && git clone https://github.com/troydm/xmonad-dbus.git $XMONAD_DEST/xmonad-dbus

stack install

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
