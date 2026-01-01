#!/bin/bash

VER="10.2.0"
FILE="fd-musl_${VER}_amd64.deb"
URL="https://github.com/sharkdp/fd/releases/download/v$VER/$FILE"

source $HOME/dotfiles/globals.sh

case $OS in
ubuntu | debian | pop | linuxmint)
    print_color green "Installing fd find for ${OS^} from ${URL}..."
    curl -fsSLO $URL
    sudo dpkg -i $FILE
    rm -rf $FILE
    ;;
*)
    FILE="fd-v${VER}-x86_64-unknown-linux-gnu"
    print_color green "Installing fd find for ${OS^} from ${URL}..."
    curl -fssLO https://github.com/sharkdp/fd/releases/download/v$VER/$FILE.tar.gz
    tar -xf $FILE.tar.gz -C . $FILE/fd
    mv $FILE/fd /usr/local/bin
    rm -rf $FILE $FILE.tar.gz
    ;;
esac
