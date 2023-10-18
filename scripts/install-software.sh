#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "Requesting elevated privileges..."
    sudo "$0" "$@" # Run the script as root
    exit $?
fi

OS=$(awk '/^ID=/' /etc/os-release | sed -e 's/ID=//' -e 's/"//g' | tr '[:upper:]' '[:lower:]')
DOTFILES_DIR="$HOME/dotfiles"
source $DOTFILES_DIR/functions.sh

print_color green "Installing Packages for $OS"

command_exists() {
    command -v $1 >/dev/null 2>&1
}

is_sudoer() {
    sudo -v >/dev/null 2>&1
}

removePackage() {
    print_color reed "Removing $1 package"
    if command_exists $1 && is_sudoer; then
        case $OS in
        ubuntu)
            apt remove -y $1
            ;;
        centos)
            sudo yum remove -y $1
            ;;
        arch)
            sudo pacman -Rns --noconfirm $1
            ;;
        esac
    fi
}

installPackages() {
    print_color green "Installing the following packages:"
    for pkg in "$@"; do
        print_color blue "  - $pkg"
    done
    case $OS in
    ubuntu | debian)
        sudo apt install -y "$@"
        ;;
    centos)
        sudo yum install -y "$@"
        ;;
    arch)
        sudo pacman -S --noconfirm "$@"
        ;;
    esac
}

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
    "ripgrep"
    "rofi"
    "snapd"
    "sqlite3"
    "stacer"
    "timeshift"
    "xwallpaper"
)

[ "$OS" == "ubuntu" ] || [ "$OS" == "debian" ] && sudo apt update

installPackages "${packages[@]}"

[ "$OS" == "ubuntu" ] || [ "$OS" == "debian" ] && sudo ln -sf /usr/bin/fdfind /usr/bin/fd
