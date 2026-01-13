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
    URL="https://github.com/sharkdp/fd/releases/download/v$VER/$FILE.tar.gz"
    print_color green "Installing fd find for ${OS^} from ${URL}..."
    curl -fssLO "$URL"
    tar -xf "$FILE.tar.gz" -C . "$FILE/fd"
    mkdir -p "$HOME/.local/bin"
    mv "$FILE/fd" "$HOME/.local/bin"
    rm -rf "$FILE" "$FILE.tar.gz"
    ;;
esac
