#!/bin/bash
OS=$(awk '/^ID=/' /etc/os-release | sed -e 's/ID=//' -e 's/"//g' | tr '[:upper:]' '[:lower:]')

if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
    sudo apt-add-repository -y ppa:fish-shell/release-3 >/dev/null 2>&1
    sudo apt update -qq -y >/dev/null >/dev/null 2>&1
fi

$PI i fish
rm -rf $HOME/.config/fish >/dev/null
ln -sf $DOTFILES_DIR/.config/fish $HOME/.config/

