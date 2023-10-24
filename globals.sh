#!/bin/bash

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

command_exists() {
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
    print_color green "Installing the following packages:"
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

print_color() {
    NC='\033[0m'

    if [ "$1" = "red" ]; then
        COLOR="\033[31m"
    fi

    if [ "$1" = "green" ]; then
        COLOR="\033[0;32m"
    fi

    printf "${COLOR}$2${NC}\n"
}
