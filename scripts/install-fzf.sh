#!/bin/bash

FORCE=$1
VER="0.42.0"

if [ "$FORCE" = true ]; then
    rm -f $HOME/.local/bin/fzf
fi

if [ ! -f "$HOME/.local/bin/fzf" ]; then
    print_color green "INSTALLING FZF..."
    curl -fsSLO https://github.com/junegunn/fzf/releases/download/$VER/fzf-$VER-linux_amd64.tar.gz
    tar -xf fzf-$VER-linux_amd64.tar.gz
    mv fzf $HOME/.local/bin
    rm -f fzf-$VER-linux_amd64.tar.gz
fi
