#!/bin/bash

export DOTFILES_DIR=$HOME/dotfiles
export OS=$(awk '/^ID=/' /etc/os-release | sed -e 's/ID=//' -e 's/"//g' | tr '[:upper:]' '[:lower:]')

add_paths_from_file() {
    local file_path="$1"

    while IFS= read -r line; do
        if [[ $line == /* ]]; then
            full_path="$line"
        else
            full_path="$HOME/$line"
        fi

        if [ -d "$full_path" ] && [[ ":$PATH:" != *":$full_path:"* ]]; then
            export PATH="$full_path:$PATH"
        fi
    done <"$file_path"
}

cd_up() {
    cd $(printf "%-1.s../" $(seq 1 $1))
}

create_dir() {
    if [ ! -d "$1" ]; then
        print_color green "Creating $1 ..."
        mkdir -p "$1"
    fi
}

cmd_exist() {
    command -v $1 >/dev/null 2>&1
}

load_env_vars() {
    if [ -f "$1" ]; then
        while IFS='=' read -r key value; do
            # Remove leading and trailing whitespace from key
            key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            # Remove leading and trailing whitespace from value
            value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            if ! [ -n "${!key}" ]; then
                export "$key"="$value"
            fi
        done <"$1"
    fi
}

load_env() {
    set -e
    ENV_FILE=$1

    if [ -f "$ENV_FILE" ]; then
        echo "Loading environment variables from $ENV_FILE"
        set -a
        source "$ENV_FILE"
        set +a
    else
        echo "Environment file $ENV_FILE does not exist"
    fi
}

is_sudoer() {
    sudo -v >/dev/null 2>&1
}

installPackages() {
    print_color green "Installing the following packages for ${OS^}:"
    for pkg in "$@"; do
        print_color blue "  - $pkg"
    done
    case $OS in
    ubuntu | debian | linuxmint)
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

print_color() {
    NC='\033[0m' # No Color

    case "$1" in
        "black")
            COLOR='\033[0;30m'
            ;;
        "red")
            COLOR='\033[0;31m'
            ;;
        "green")
            COLOR='\033[0;32m'
            ;;
        "yellow")
            COLOR='\033[0;33m'
            ;;
        "blue")
            COLOR='\033[0;34m'
            ;;
        "magenta")
            COLOR='\033[0;35m'
            ;;
        "cyan")
            COLOR='\033[0;36m'
            ;;
        "white")
            COLOR='\033[0;37m'
            ;;
        "bold_black")
            COLOR='\033[1;30m'
            ;;
        "bold_red")
            COLOR='\033[1;31m'
            ;;
        "bold_green")
            COLOR='\033[1;32m'
            ;;
        "bold_yellow")
            COLOR='\033[1;33m'
            ;;
        "bold_blue")
            COLOR='\033[1;34m'
            ;;
        "bold_magenta")
            COLOR='\033[1;35m'
            ;;
        "bold_cyan")
            COLOR='\033[1;36m'
            ;;
        "bold_white")
            COLOR='\033[1;37m'
            ;;
        "underline_black")
            COLOR='\033[4;30m'
            ;;
        "underline_red")
            COLOR='\033[4;31m'
            ;;
        "underline_green")
            COLOR='\033[4;32m'
            ;;
        "underline_yellow")
            COLOR='\033[4;33m'
            ;;
        "underline_blue")
            COLOR='\033[4;34m'
            ;;
        "underline_magenta")
            COLOR='\033[4;35m'
            ;;
        "underline_cyan")
            COLOR='\033[4;36m'
            ;;
        "underline_white")
            COLOR='\033[4;37m'
            ;;
        "background_black")
            COLOR='\033[40m'
            ;;
        "background_red")
            COLOR='\033[41m'
            ;;
        "background_green")
            COLOR='\033[42m'
            ;;
        "background_yellow")
            COLOR='\033[43m'
            ;;
        "background_blue")
            COLOR='\033[44m'
            ;;
        "background_magenta")
            COLOR='\033[45m'
            ;;
        "background_cyan")
            COLOR='\033[46m'
            ;;
        "background_white")
            COLOR='\033[47m'
            ;;
        *)
            COLOR='\033[0m' # Default to no color
            ;;
    esac

    printf "${COLOR}$2${NC}\n"
}

hold_packages() {
    case $OS in
    ubuntu | debian | linuxmint)
        sudo apt-mark hold $packages > /dev/null
        ;;
    centos)
        echo "Warning: CentOS does not support holding packages directly."
        ;;
    arch)
        echo "Warning: Arch Linux does not support holding packages directly."
        ;;
    *)
        echo "Unsupported OS: $OS"
        exit 1
        ;;
    esac
}

unhold_packages() {
    case $OS in
    ubuntu | debian | linuxmint)
        sudo apt-mark unhold $packages > /dev/null
        ;;
    centos)
        echo "Warning: CentOS does not support unholding packages directly."
        ;;
    arch)
        echo "Warning: Arch Linux does not support unholding packages directly."
        ;;
    *)
        echo "Unsupported OS: $OS"
        exit 1
        ;;
    esac
}

removePackage() {
    if is_sudoer; then
        case $OS in
        ubuntu | debian | linuxmint)
            sudo apt remove --purge --allow-change-held-packages -y "$@"
            ;;
        centos)
            sudo yum remove -y "$@"
            ;;
        arch)
            sudo pacman -Rns --noconfirm "$@"
            ;;
        *)
            echo "Unsupported OS: $OS"
            exit 1
            ;;
        esac
    else
        echo "Error: You do not have sudo privileges."
        exit 1
    fi
}

source_script() {
    local script_name=$1
    local script_path="$DOTFILES/env/$script_name.sh"
    [[ -f $script_path ]] && source $script_path || echo "Failed to source $script_path"
}
