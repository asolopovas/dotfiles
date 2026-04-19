#!/bin/bash

export DOTFILES_DIR="$HOME/dotfiles"

# Cross-platform OS detection
detect_os() {
    case "$(uname -s)" in
        Darwin) echo "macos" ;;
        Linux)
            if [ -f /etc/os-release ]; then
                awk -F= '/^ID=/ {gsub(/"/, "", $2); print tolower($2)}' /etc/os-release
            elif [ -f /etc/debian_version ]; then
                echo "debian"
            elif [ -f /etc/fedora-release ]; then
                echo "fedora"
            elif [ -f /etc/arch-release ]; then
                echo "arch"
            else
                echo "linux"
            fi
            ;;
        *) echo "unknown" ;;
    esac
}

# Architecture detection (normalised labels)
detect_arch() {
    local machine
    machine="$(uname -m)"
    case "$machine" in
        x86_64|amd64)  echo "x86_64" ;;
        aarch64|arm64) echo "aarch64" ;;
        armv7l)        echo "armv7l" ;;
        *)             echo "$machine" ;;
    esac
}

OS="${OS:-$(detect_os)}"
ARCH="${ARCH:-$(detect_arch)}"
export OS ARCH

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

# Fix broken symlinks in a directory (non-recursive by default)
# Usage: fix_broken_symlinks /path/to/dir [--recursive]
fix_broken_symlinks() {
    local dir="${1:-.}"
    local recursive="${2:-}"
    local depth_args=(-maxdepth 1)
    local count=0

    if [ "$recursive" = "--recursive" ]; then
        depth_args=()
    fi

    if [ ! -d "$dir" ]; then
        return 0
    fi

    while IFS= read -r -d '' link; do
        local target
        target="$(readlink "$link")"
        print_color yellow "Removing broken symlink: $link -> $target"
        rm -f "$link"
        count=$((count + 1))
    done < <(find "$dir" "${depth_args[@]}" -xtype l -print0 2>/dev/null)

    if [ "$count" -gt 0 ]; then
        print_color green "Fixed $count broken symlink(s) in $dir"
    fi
    return 0
}

# Resolve latest release tag for a GitHub repo (strips leading 'v' by default).
# Usage: gh_latest_release owner/repo [--keep-v]
gh_latest_release() {
    local repo="$1"
    local keep_v="${2:-}"
    local tag

    tag=$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null \
        | grep -m1 '"tag_name"' | cut -d'"' -f4)

    if [ -z "$tag" ]; then
        echo "Failed to fetch latest release for $repo" >&2
        return 1
    fi

    [ "$keep_v" = "--keep-v" ] || tag="${tag#v}"
    printf '%s\n' "$tag"
}

# Ensure a command exists; if missing, prompt to run the given install script.
# Usage: require_cmd <cmd> <install-script-relative-to-DOTFILES_DIR>
require_cmd() {
    local cmd="$1"
    local script="$2"
    if cmd_exist "$cmd"; then
        return 0
    fi
    print_color red "$cmd is required ($script)"
    local reply
    read -r -p "Run $script now? [y/N] " reply
    case "$reply" in
        [Yy]|[Yy][Ee][Ss])
            bash "$DOTFILES_DIR/$script" || return 1
            hash -r
            if ! cmd_exist "$cmd"; then
                export PATH="/usr/local/go/bin:$HOME/go/bin:$HOME/.local/bin:$HOME/.nvm/versions/node/current/bin:$PATH"
            fi
            if ! cmd_exist "$cmd"; then
                print_color red "$cmd still not found after install"
                return 1
            fi
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Portable package install (apt/brew/dnf/pacman)
pkg_install() {
    case "$OS" in
        ubuntu|debian|linuxmint|pop)
            ${SUDO:-} apt install -y "$@" ;;
        fedora)
            ${SUDO:-} dnf install -y "$@" ;;
        centos)
            ${SUDO:-} yum install -y "$@" ;;
        arch)
            ${SUDO:-} pacman -S --noconfirm "$@" ;;
        macos)
            brew install "$@" ;;
        *)
            echo "Unsupported OS for package install: $OS"
            return 1 ;;
    esac
}
