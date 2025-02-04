#!/bin/bash

source $HOME/dotfiles/globals.sh


print_color green "Installing Neovim for ${OS^} ..."

if [ "$FORCE" = true ]; then
    print_color red "FORCE Enabled: Removing ${AUTOLOAD_DIR} ..."
    rm -rf $AUTOLOAD_DIR
fi

case $OS in
ubuntu | debian | linuxmint | pop)
    removePackage vim
    installPackages neovim python3-neovim
    ;;
alipne)
    installPackages neovim py3-pynvim
esac


