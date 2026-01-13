#!/bin/bash

VER="10.3.0"
FILE="fd-v${VER}-x86_64-unknown-linux-gnu"
URL="https://github.com/sharkdp/fd/releases/download/v$VER/$FILE.tar.gz"

source $HOME/dotfiles/globals.sh

print_color green "Installing fd find for ${OS^} from ${URL}..."
curl -fssLO "$URL"
tar -xf "$FILE.tar.gz" -C . "$FILE/fd"
mkdir -p "$HOME/.local/bin"
mv "$FILE/fd" "$HOME/.local/bin"
rm -rf "$FILE" "$FILE.tar.gz"
