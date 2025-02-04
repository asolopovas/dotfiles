#!/bin/bash

source $HOME/dotfiles/globals.sh

AUTOLOAD_DIR="$HOME/.local/share/nvim/site/autoload"

print_color green "Installing Neovim for ${OS^} ..."

if [ "$FORCE" = true ]; then
    print_color red "FORCE Enabled: Removing ${AUTOLOAD_DIR} ..."
    rm -rf $AUTOLOAD_DIR
fi

case $OS in
ubuntu | debian | linuxmint | pop)
    removePackage vim
    if ! cmd_exist nvim; then
        installPackages neovim python3-neovim
    fi
    ;;
esac

if [ ! -d "$AUTOLOAD_DIR" ]; then
    print_color green "Installing vim-plug ..."
    curl -sfLo $AUTOLOAD_DIR/plug.vim --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    bash -c "nvim +silent +PlugInstall +qall"
fi

ln -sf $(which nvim) $HOME/.local/bin
ln -sf $(which nvim) $HOME/.local/bin/vim
