#!/bin/bash

DOTFILES_DIR="$HOME/dotfiles"
source $DOTFILES_DIR/globals.sh

print_color green "Installing Packages for ${OS^}"

packages=(
    "dunst"
    "fish"
    "flameshot"
    "fzf"
    "htop"
    "jq"
    "libgtkglext1"
    "libguestfs-tools"
    "libnss3-tools"
    "lxappearance"
    "polybar"
    "playerctl"
    "ripgrep"
    "rofi"
    "sqlite3"
    "stacer"
    "timeshift"
    "xwallpaper"
)

installPackages "${packages[@]}"

case $OS in
ubuntu | debian | pop | linuxmint)
    sudo apt update
    sudo ln -sf /usr/bin/fdfind /usr/bin/fd
    ;;
esac
