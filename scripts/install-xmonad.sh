#!/bin/bash

XMONAD_ORIGIN=$HOME/dotfiles/.config/xmonad/

ln -sf $XMONAD_ORIGIN $XDG_CONFIG_HOME/xmonad


xmonadLog="$GOPATH/src/github.com/xintron"
if [ ! -d $xmonadLog ]; then
    mkdir -p $xmonadLog
    pushd $xmonadLog
    git clone https://github.com/xintron/xmonad-log.git
    go get github.com/godbus/dbus
    go mod init
    go build
    go install
fi

pushd $XMONAD_ORIGIN

if [ ! -d ./xmonad ]; then
    git clone --branch v0.17.1 https://github.com/xmonad/xmonad
fi

if [ ! -d ./xmonad-contrib ]; then
    git clone --branch v0.17.1 https://github.com/xmonad/xmonad-contrib
fi

if [ ! -d ./xmonad-dbus ]; then
    git clone https://github.com/troydm/xmonad-dbus.git
fi

# if haskell installed
if ! command -v stack &>/dev/null; then
    curl -sSL https://get.haskellstack.org/ | sh
fi
stack install

sudo tee /usr/share/xsessions/xmonad.desktop >/dev/null <<EOT
[Desktop Entry]
Name=Xmonad
Comment=Lightweight Tiling Window Manager
Exec=$HOME/.cache/xmonad/xmonad-x86_64-linux
Type=XSession
DesktopNames=Xmonad
EOT
