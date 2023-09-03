#!/bin/bash

source ./os.sh

if [ "$OS" = "ubuntu" ] || [ ""$OS"" = "debian" ]; then
    print_color green "INSTALLING FD-FIND..."
    curl -fsSLO https://github.com/sharkdp/fd/releases/download/v8.5.3/fd-musl_8.5.3_amd64.deb
    sudo dpkg -i fd-musl_8.5.3_amd64.deb
    rm -rf fd-musl_8.5.3_amd64.deb
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
