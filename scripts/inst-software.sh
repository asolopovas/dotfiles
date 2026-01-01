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
    "subversion"
    "polybar"
    "playerctl"
    "ripgrep"
    "pulsemixer"
    "rofi"
    "picom"
    "sqlite3"
    "btop"
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
