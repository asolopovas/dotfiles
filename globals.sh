#!/bin/bash

export DOTFILES_DIR="$HOME/dotfiles"
OS=$(awk -F= '/^ID=/ {gsub(/"/, "", $2); print tolower($2)}' /etc/os-release)
export OS

add_paths_from_file() {
    local file_path="$1"

    while IFS= read -r line; do
        local full_path
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
    cd "$(printf "%-1.s../" $(seq 1 "$1"))" || return
}

create_dir() {
    if [ ! -d "$1" ]; then
        print_color green "Creating $1 ..."
        mkdir -p "$1"
    fi
}

cmd_exist() {
    command -v "$1" >/dev/null 2>&1
}

load_env_vars() {
    [ -f "$1" ] || return 0
    while IFS='=' read -r key value || [ -n "$key" ]; do
        key="${key#"${key%%[![:space:]]*}"}"
        key="${key%"${key##*[![:space:]]}"}"
        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"
        if [ -n "$key" ] && [ -z "${!key:-}" ]; then
            export "$key"="$value"
        fi
    done <"$1"
    return 0
}

load_env() {
    set -e
    local env_file="$1"

    if [ -f "$env_file" ]; then
        echo "Loading environment variables from $env_file"
        set -a
        # shellcheck disable=SC1090
        source "$env_file"
        set +a
    else
        echo "Environment file $env_file does not exist"
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
    local NC='\033[0m'
    local -A colors=(
        [black]='\033[0;30m'    [red]='\033[0;31m'      [green]='\033[0;32m'
        [yellow]='\033[0;33m'   [blue]='\033[0;34m'     [magenta]='\033[0;35m'
        [cyan]='\033[0;36m'     [white]='\033[0;37m'
        [bold_black]='\033[1;30m'   [bold_red]='\033[1;31m'     [bold_green]='\033[1;32m'
        [bold_yellow]='\033[1;33m'  [bold_blue]='\033[1;34m'    [bold_magenta]='\033[1;35m'
        [bold_cyan]='\033[1;36m'    [bold_white]='\033[1;37m'
        [underline_black]='\033[4;30m'  [underline_red]='\033[4;31m'    [underline_green]='\033[4;32m'
        [underline_yellow]='\033[4;33m' [underline_blue]='\033[4;34m'   [underline_magenta]='\033[4;35m'
        [underline_cyan]='\033[4;36m'   [underline_white]='\033[4;37m'
        [background_black]='\033[40m'   [background_red]='\033[41m'     [background_green]='\033[42m'
        [background_yellow]='\033[43m'  [background_blue]='\033[44m'    [background_magenta]='\033[45m'
        [background_cyan]='\033[46m'    [background_white]='\033[47m'
    )
    printf '%b%s%b\n' "${colors[$1]:-$NC}" "$2" "$NC"
}

hold_packages() {
    case $OS in
    ubuntu | debian | linuxmint)
        sudo apt-mark hold "$@" >/dev/null
        ;;
    *)
        echo "Warning: $OS does not support holding packages directly."
        ;;
    esac
}

unhold_packages() {
    case $OS in
    ubuntu | debian | linuxmint)
        sudo apt-mark unhold "$@" >/dev/null
        ;;
    *)
        echo "Warning: $OS does not support unholding packages directly."
        ;;
    esac
}

removePackage() {
    if ! is_sudoer; then
        echo "Error: You do not have sudo privileges."
        exit 1
    fi
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
}

source_script() {
    local script_name="$1"
    local script_path="$DOTFILES/env/$script_name.sh"
    # shellcheck disable=SC1090
    [[ -f "$script_path" ]] && source "$script_path" || echo "Failed to source $script_path"
}
