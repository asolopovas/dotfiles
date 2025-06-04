#!/usr/bin/env bash

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
rm -rf /opt/nvim
tar -C /opt -xzf nvim-linux-x86_64.tar.gz
rm -f nvim-linux-x86_64.tar.gz
ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/bin/vim

/opt/nvim-linux-x86_64/bin/nvim --headless +"autocmd User LazyDone ++once qa"
