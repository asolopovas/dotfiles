#!/bin/bash

source $HOME/dotfiles/functions.sh
OS=$(awk '/^ID=/' /etc/os-release | sed -e 's/ID=//' -e 's/"//g' | tr '[:upper:]' '[:lower:]')
PI="$HOME/.tmp/p"

print_color green "INSTALLING NEOVIM..."


if [ "$OS" = "ubuntu" ] || [ ""$OS"" = "debian" ]; then
    $PI r vim
    $PI i neovim python3-neovim
fi

if [ "$OS" = "alpine" ]; then
    $PI i neovim py3-pynvim
fi

if [ "$FORCE" = true ]; then
    rm -rf $HOME/.local/share/nvim/site/autoload
fi

if [ ! -d "$HOME/.local/share/nvim/site/autoload" ]; then
    print_color green "INSTALLING NVIM PLUG..."
    curl -sfLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    bash -c "nvim +silent +PlugInstall +qall"
fi

ln -sf $(which nvim) $HOME/.local/bin
ln -sf $(which nvim) $HOME/.local/bin/vim
