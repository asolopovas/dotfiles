#!/bin/bash

source $HOME/dotfiles/globals.sh

AUTOLOAD_DIR="$HOME/.local/share/nvim/site/autoload"

if ! cmd_exist nvim; then
    curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
    rm -rf /opt/nvim
    tar -C /opt -xzf nvim-linux-x86_64.tar.gz
fi

if [ ! -d "$AUTOLOAD_DIR" ]; then
    print_color green "Installing vim-plug ..."
    curl -sfLo $AUTOLOAD_DIR/plug.vim --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    bash -c "nvim +silent +PlugInstall +qall"
fi

