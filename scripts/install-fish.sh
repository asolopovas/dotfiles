#!/bin/bash

source "$HOME/dotfiles/globals.sh"

case $OS in
ubuntu | debian | linuxmint | pop)
    sudo apt-add-repository -y ppa:fish-shell/release-3
    sudo apt update -qq -y
    sudo apt install fish -y
    ;;
esac

