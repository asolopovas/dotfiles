#!/usr/bin/env bash
set -euo pipefail

source "$HOME/dotfiles/globals.sh"

DEFAULT_VERSION="8.3"
MIN_PHP_VERSION="8.2"
ACTION="install"
REQUESTED_VERSION=""
PACKAGE_INPUT=""
SELECTED_PACKAGES=()

PACKAGE_CHOICES=(
    cli common fpm bcmath bz2 curl gd igbinary imagick intl mbstring
    mongodb mysql opcache pcov pgsql phpdbg readline redis soap sqlite3
    xdebug xml yaml zip
)

DEFAULT_PACKAGE_CHOICES=(cli common)

usage() {
    cat <<EOF
Usage: inst-php.sh [ACTION] [VERSION] [OPTIONS]

Actions:
  install             Choose one PHP version and package set to install
  remove, uninstall   Remove one PHP version
  list                Show installed versioned PHP packages

Options:
  -v, --version X.Y       Use PHP version without prompting
  -p, --packages LIST     Space or comma separated package names
  --all                   Install every available package in the menu
  -h, --help              Show this help

Examples:
  inst-php.sh
  inst-php.sh install 8.3 --packages "cli common curl mbstring xml zip"
  inst-php.sh --version 8.4 --packages cli,curl,mbstring
  inst-php.sh remove 8.2
  inst-php.sh list

Interactive choices use fzf.
The install menu offers PHP $MIN_PHP_VERSION and newer.
The install action removes other installed versioned PHP packages first.
Apt may still add dependency packages required by your choices.
EOF
}

error_exit() {
    print_color red "$1"
    exit 1
}

is_php_version() {
    [[ "$1" =~ ^[0-9]+\.[0-9]+$ ]]
}

php_version_supported() {
    local first
    first="$(printf '%s\n%s\n' "$MIN_PHP_VERSION" "$1" | sort -V | head -n 1)"
    [ "$first" = "$MIN_PHP_VERSION" ]
}

require_apt_system() {
    case "$OS" in
        ubuntu | debian | linuxmint | pop) ;;
        *) error_exit "PHP version selection is only supported on apt based systems here." ;;
    esac
}

require_fzf() {
    if ! cmd_exist fzf; then
        error_exit "fzf is required for interactive choices. Install it or pass --version and --packages."
    fi
}

validate_requested_version() {
    if [ -z "$REQUESTED_VERSION" ]; then
        return 0
    fi
    if ! is_php_version "$REQUESTED_VERSION"; then
        error_exit "Invalid PHP version: $REQUESTED_VERSION"
    fi
    if [ "$ACTION" = "install" ] && ! php_version_supported "$REQUESTED_VERSION"; then
        error_exit "Install supports PHP $MIN_PHP_VERSION and newer."
    fi
}

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -h | --help)
                usage
                exit 0
                ;;
            install)
                ACTION="install"
                shift
                ;;
            remove | uninstall)
                ACTION="remove"
                shift
                ;;
            list)
                ACTION="list"
                shift
                ;;
            -v | --version)
                [ "$#" -ge 2 ] || error_exit "Missing value for $1"
                REQUESTED_VERSION="$2"
                shift 2
                ;;
            --version=*)
                REQUESTED_VERSION="${1#*=}"
                shift
                ;;
            -p | --packages)
                [ "$#" -ge 2 ] || error_exit "Missing value for $1"
                PACKAGE_INPUT="$2"
                shift 2
                ;;
            --packages=*)
                PACKAGE_INPUT="${1#*=}"
                shift
                ;;
            --all)
                PACKAGE_INPUT="all"
                shift
                ;;
            *)
                if is_php_version "$1"; then
                    REQUESTED_VERSION="$1"
                    shift
                else
                    error_exit "Unknown argument: $1"
                fi
                ;;
        esac
    done
}

ensure_ppa() {
    case "$OS" in
        ubuntu | linuxmint | pop)
            if ! grep -rqh "ondrej/php" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
                print_color green "Adding ondrej/php PPA ..."
                sudo add-apt-repository -y ppa:ondrej/php
                sudo apt update
            fi
            ;;
        debian)
            if ! grep -rqh "packages.sury.org/php" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
                print_color green "Adding sury.org PHP repo ..."
                SUDO=sudo pkg_install lsb-release ca-certificates curl gnupg
                sudo curl -fsSLo /etc/apt/trusted.gpg.d/sury-php.gpg https://packages.sury.org/php/apt.gpg
                echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" |
                    sudo tee /etc/apt/sources.list.d/sury-php.list >/dev/null
                sudo apt update
            fi
            ;;
    esac
}

package_exists() {
    apt-cache show "$1" >/dev/null 2>&1
}

available_versions() {
    local version
    apt-cache pkgnames php 2>/dev/null |
        grep -E '^php[0-9]+\.[0-9]+$' |
        sed 's/^php//' |
        sort -Vr |
        while IFS= read -r version; do
            if php_version_supported "$version"; then
                printf '%s\n' "$version"
            fi
        done || true
}

installed_php_packages() {
    dpkg -l 'php*' 2>/dev/null |
        awk '/^[ih]i/ {print $2}' |
        sed 's/:.*//' |
        grep -E '^php[0-9]+\.[0-9]+($|-)' |
        sort -u || true
}

installed_versions() {
    installed_php_packages |
        sed -E 's/^php([0-9]+\.[0-9]+).*/\1/' |
        sort -Vr |
        uniq || true
}

list_installed_php() {
    local packages
    packages="$(installed_php_packages)"
    if [ -z "$packages" ]; then
        print_color yellow "No versioned PHP packages are installed."
        return 0
    fi
    print_color green "Installed versioned PHP packages:"
    printf '%s\n' "$packages"
}

choose_version() {
    if [ -n "$REQUESTED_VERSION" ]; then
        is_php_version "$REQUESTED_VERSION" || error_exit "Invalid PHP version: $REQUESTED_VERSION"
        VER="$REQUESTED_VERSION"
        return 0
    fi

    if [ ! -t 0 ]; then
        VER="$DEFAULT_VERSION"
        return 0
    fi

    local versions=()
    mapfile -t versions < <(available_versions)

    if [ "${#versions[@]}" -eq 0 ]; then
        VER="$DEFAULT_VERSION"
        return 0
    fi

    require_fzf

    VER="$(printf '%s\n' "${versions[@]}" | fzf --height=40% --reverse --prompt="PHP version> " --header="PHP $MIN_PHP_VERSION and newer" || true)"
    [ -n "$VER" ] || error_exit "Cancelled."
}

choose_installed_version() {
    if [ -n "$REQUESTED_VERSION" ]; then
        VER="$REQUESTED_VERSION"
        return 0
    fi

    if [ ! -t 0 ]; then
        error_exit "Choose a PHP version to remove."
    fi

    local versions=()
    mapfile -t versions < <(installed_versions)
    [ "${#versions[@]}" -gt 0 ] || error_exit "No versioned PHP packages are installed."

    require_fzf
    VER="$(printf '%s\n' "${versions[@]}" | fzf --height=40% --reverse --prompt="Remove PHP version> " --header="Installed PHP versions" || true)"
    [ -n "$VER" ] || error_exit "Cancelled."
}

available_package_choices() {
    local version="$1"
    local item
    for item in "${PACKAGE_CHOICES[@]}"; do
        if package_exists "php$version-$item"; then
            printf '%s\n' "$item"
        fi
    done
}

choice_available() {
    local needle="$1"
    shift
    local item
    for item in "$@"; do
        [ "$item" = "$needle" ] && return 0
    done
    return 1
}

add_selected_package() {
    local package="$1"
    local existing
    for existing in "${SELECTED_PACKAGES[@]}"; do
        [ "$existing" = "$package" ] && return 0
    done
    SELECTED_PACKAGES+=("$package")
}

parse_package_input() {
    local version="$1"
    local input="$2"
    shift 2
    local available=("$@")
    local tokens=()
    local token

    SELECTED_PACKAGES=()
    input="${input//,/ }"
    read -r -a tokens <<<"$input"

    for token in "${tokens[@]}"; do
        [ -n "$token" ] || continue
        if [ "$token" = "all" ]; then
            local item
            for item in "${available[@]}"; do
                add_selected_package "php$version-$item"
            done
            continue
        fi
        token="${token#php$version-}"
        if ! choice_available "$token" "${available[@]}"; then
            error_exit "Package php$version-$token is not available."
        fi
        add_selected_package "php$version-$token"
    done

    [ "${#SELECTED_PACKAGES[@]}" -gt 0 ] || error_exit "No PHP packages selected."
}

choose_packages() {
    local version="$1"
    local available=()
    mapfile -t available < <(available_package_choices "$version")

    [ "${#available[@]}" -gt 0 ] || error_exit "No packages are available for PHP $version."

    if ! package_exists "php$version"; then
        error_exit "PHP $version is not available from apt."
    fi

    local input="$PACKAGE_INPUT"
    if [ -n "$input" ]; then
        parse_package_input "$version" "$input" "${available[@]}"
        return 0
    fi

    if [ ! -t 0 ]; then
        parse_package_input "$version" "${DEFAULT_PACKAGE_CHOICES[*]}" "${available[@]}"
        return 0
    fi

    require_fzf
    local choices=()
    mapfile -t choices < <(printf '%s\n' "${available[@]}" | fzf --multi --height=70% --reverse --prompt="PHP $version packages> " --header="Tab selects packages. Enter confirms." || true)
    [ "${#choices[@]}" -gt 0 ] || error_exit "No PHP packages selected."

    local choice
    for choice in "${choices[@]}"; do
        add_selected_package "php$version-$choice"
    done
}

remove_packages_if_needed() {
    local packages=("$@")
    [ "${#packages[@]}" -gt 0 ] || return 0
    print_color yellow "Removing packages that should not remain installed:"
    printf '  %s\n' "${packages[@]}"

    if [ -t 0 ]; then
        require_fzf
        local reply
        reply="$(printf 'no\nyes\n' | fzf --height=20% --reverse --prompt="Remove these packages?> " || true)"
        [ "$reply" = "yes" ] || error_exit "Cancelled."
    fi

    unhold_packages "${packages[@]}" || true
    removePackage "${packages[@]}"
}

selected_package() {
    local package="$1"
    local selected
    for selected in "${SELECTED_PACKAGES[@]}"; do
        [ "$selected" = "$package" ] && return 0
    done
    return 1
}

remove_unwanted_php_packages() {
    local version="$1"
    local installed=()
    local remove=()
    local package
    mapfile -t installed < <(installed_php_packages)

    for package in "${installed[@]}"; do
        if [[ "$package" != php"$version" && "$package" != php"$version"-* ]]; then
            remove+=("$package")
        elif ! selected_package "$package"; then
            remove+=("$package")
        fi
    done

    remove_packages_if_needed "${remove[@]}"
}

set_php_alternatives() {
    local version="$1"
    local name
    for name in php phar phar.phar phpize php-config; do
        if [ -x "/usr/bin/$name$version" ]; then
            sudo update-alternatives --set "$name" "/usr/bin/$name$version" >/dev/null 2>&1 || true
        fi
    done
}

install_php() {
    ensure_ppa
    choose_version
    choose_packages "$VER"

    print_color green "PHP $VER selected packages:"
    printf '  %s\n' "${SELECTED_PACKAGES[@]}"

    remove_unwanted_php_packages "$VER"
    unhold_packages "${SELECTED_PACKAGES[@]}" || true
    installPackages "${SELECTED_PACKAGES[@]}"
    hold_packages "${SELECTED_PACKAGES[@]}"
    set_php_alternatives "$VER"

    print_color green "PHP $VER is installed with your selected package set."
}

remove_php() {
    choose_installed_version
    local installed=()
    local remove=()
    local package
    mapfile -t installed < <(installed_php_packages)

    for package in "${installed[@]}"; do
        if [[ "$package" == php"$VER" || "$package" == php"$VER"-* ]]; then
            remove+=("$package")
        fi
    done

    if [ "${#remove[@]}" -eq 0 ]; then
        print_color yellow "No PHP $VER packages are installed."
        return 0
    fi

    remove_packages_if_needed "${remove[@]}"
    print_color green "PHP $VER packages removed."
}

main() {
    parse_args "$@"
    require_apt_system
    validate_requested_version

    case "$ACTION" in
        install)
            install_php
            ;;
        remove)
            remove_php
            ;;
        list)
            list_installed_php
            ;;
    esac
}

main "$@"
