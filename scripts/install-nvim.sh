#!/usr/bin/env bash

INSTALL_ARCHIVE=nvim-linux-x86_64.tar.gz
URL="https://github.com/neovim/neovim/releases/latest/download/$INSTALL_ARCHIVE"

if [ "$(id -u)" -ne 0 ]; then
    DIR="$HOME/.local"
    BIN="$DIR/bin"
    mkdir -p "$BIN"
    curl -LO "$URL"
    tar -xzf "$INSTALL_ARCHIVE" -C "$DIR"
    mv "$DIR/nvim-linux-x86_64" "$DIR/nvim"
    ln -sf "$DIR/nvim/bin/nvim" "$BIN/vim"
else
    curl -LO "$URL"
    rm -rf /opt/nvim
    tar -C /opt -xzf "$INSTALL_ARCHIVE"
    rm -f "$INSTALL_ARCHIVE"
    ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/bin/vim
fi

rm -f "$INSTALL_ARCHIVE"
