#!/bin/bash
export OS=$(awk '/^ID=/' /etc/os-release | sed -e 's/ID=//' -e 's/"//g' | tr '[:upper:]' '[:lower:]')

print_color() {
    declare -A colors=(
        ['red']='\033[31m'
        ['green']='\033[0;32m'
    )
    echo -e "${colors[$1]}$2\033[0m"
}

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
            sudo apt remove -y "$@"
            ;;
        centos)
            sudo yum remove -y "$@"
            ;;
        arch)
            sudo pacman -Rns --noconfirm "$@"
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
    ubuntu|debian|linuxmint)
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
