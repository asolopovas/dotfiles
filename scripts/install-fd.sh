#!/bin/bash

source $HOME/dotfiles/globals.sh

if [ "$OS" = "ubuntu" ] || [ ""$OS"" = "debian" ] || [ ""$OS"" = "pop" ] || [ ""$OS"" = "linuxmint" ]; then
    VER="8.7.0"
    FILE="fd-musl_${VER}_amd64.deb"
    URL="https://github.com/sharkdp/fd/releases/download/v$VER/$FILE"

    print_color green "INSTALLING FD-FIND..."
    echo $URL

    curl -fsSLO $URL
    sudo dpkg -i $FILE
    rm -rf $FILE
fi

if [ "$OS" = "almalinux" ]; then
    VER="8.7.0"
    NAME="fd-v${VER}-x86_64-unknown-linux-gnu"
    curl -fssLO https://github.com/sharkdp/fd/releases/download/v$VER/$NAME.tar.gz
    tar -xf $NAME.tar.gz -C . $NAME/fd
    mv $NAME/fd /usr/local/bin
    rm -rf $NAME $NAME.tar.gz
fi

if [ "$OS" = "alpine" ]; then
    $PI i fd
fi
