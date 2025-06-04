#!/usr/bin/env bash

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Install Neovim
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
rm -rf /opt/nvim
tar -C /opt -xzf nvim-linux-x86_64.tar.gz
rm -f nvim-linux-x86_64.tar.gz
ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/bin/vim

# Wait for Lazy.nvim setup to finish
/opt/nvim-linux-x86_64/bin/nvim --headless +"autocmd User LazyDone ++once qa" +Lazy sync

# Update Mason tools (if mason-tool-installer is used)
/opt/nvim-linux-x86_64/bin/nvim --headless -c "lua require('mason-tool-installer').run_on_start()" -c 'qa'
