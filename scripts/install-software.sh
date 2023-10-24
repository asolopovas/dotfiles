#!/bin/bash

source $DOTFILES_DIR/functions.sh

DOTFILES_DIR="$HOME/dotfiles"


print_color green "Installing Packages for $OS"

packages=(
    "fd-find"
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

[ "$OS" == "ubuntu" ] || [ "$OS" == "debian" ] && sudo apt update

installPackages "${packages[@]}"

[ "$OS" == "ubuntu" ] || [ "$OS" == "debian" ] && sudo ln -sf /usr/bin/fdfind /usr/bin/fd
