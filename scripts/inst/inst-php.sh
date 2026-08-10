#!/usr/bin/env bash
set -euo pipefail

source "$HOME/dotfiles/globals.sh"

MIN_PHP_VERSION="8.2"
ACTION="install"
REQUESTED_VERSION=""
VER=""
PHP_PACKAGES=()

COMMON_EXTENSIONS=(
    cli common fpm bcmath bz2 curl gd imagick intl mbstring mysql
    opcache readline soap sqlite3 xml zip
)

usage() {
    cat <<EOF
Usage: inst-php.sh [ACTION] [VERSION]

Actions:
  install, update     Install a common PHP package set or update it
  remove, uninstall   Remove every package for one PHP version
  list                Show installed versioned PHP packages

Examples:
  inst-php.sh
  inst-php.sh 8.4
  inst-php.sh install 8.4
  inst-php.sh update 8.4
  inst-php.sh remove 8.3
  inst-php.sh list

With no arguments, the newest supported PHP version available from apt is installed or updated.
Pass VERSION to install or update a specific version.
fzf selects an installed version when removal is run without VERSION.
Installing a version does not remove or hold any other PHP packages.
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
        ubuntu | debian | linuxmint) ;;
        *) error_exit "Versioned PHP installation is supported only on Ubuntu, Debian, and Linux Mint." ;;
    esac
}

require_fzf() {
    if ! cmd_exist fzf; then
        error_exit "fzf is required for interactive version selection. Pass a version explicitly or install fzf."
    fi
}

parse_args() {
    case "${1:-install}" in
        -h | --help)
            usage
            exit 0
            ;;
        install | update)
            [ "$#" -le 2 ] || error_exit "Usage: inst-php.sh $1 [VERSION]"
            REQUESTED_VERSION="${2:-}"
            ;;
        remove | uninstall)
            [ "$#" -le 2 ] || error_exit "Usage: inst-php.sh remove [VERSION]"
            ACTION="remove"
            REQUESTED_VERSION="${2:-}"
            ;;
        list)
            [ "$#" -eq 1 ] || error_exit "Usage: inst-php.sh list"
            ACTION="list"
            ;;
        *)
            if [ "$#" -ne 1 ] || ! is_php_version "$1"; then
                error_exit "Unknown argument: $1"
            fi
            REQUESTED_VERSION="$1"
            ;;
    esac
}

validate_requested_version() {
    [ -n "$REQUESTED_VERSION" ] || return 0

    if ! is_php_version "$REQUESTED_VERSION"; then
        error_exit "Invalid PHP version: $REQUESTED_VERSION"
    fi

    if [ "$ACTION" = "install" ] && ! php_version_supported "$REQUESTED_VERSION"; then
        error_exit "Install supports PHP $MIN_PHP_VERSION and newer."
    fi
}

ensure_ubuntu_repository() {
    if grep -rqs "ondrej/php" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
        return 0
    fi

    if ! cmd_exist add-apt-repository; then
        SUDO="sudo env DEBIAN_FRONTEND=noninteractive" pkg_install software-properties-common
    fi

    print_color green "Adding ondrej/php PPA ..."
    sudo add-apt-repository -y ppa:ondrej/php
}

ensure_debian_repository() {
    if grep -rqs "packages.sury.org/php" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
        return 0
    fi

    local keyring_package
    SUDO="sudo env DEBIAN_FRONTEND=noninteractive" pkg_install lsb-release ca-certificates curl
    keyring_package="$(mktemp --suffix=.deb)"

    if ! curl -fsSLo "$keyring_package" https://packages.sury.org/debsuryorg-archive-keyring.deb; then
        rm -f "$keyring_package"
        error_exit "Failed to download the deb.sury.org archive keyring."
    fi

    if ! sudo dpkg -i "$keyring_package"; then
        rm -f "$keyring_package"
        error_exit "Failed to install the deb.sury.org archive keyring."
    fi
    rm -f "$keyring_package"

    printf 'deb [signed-by=/usr/share/keyrings/debsuryorg-archive-keyring.gpg] https://packages.sury.org/php/ %s main\n' "$(lsb_release -sc)" |
        sudo tee /etc/apt/sources.list.d/php.list >/dev/null
}

ensure_php_repository() {
    case "$OS" in
        ubuntu | linuxmint)
            ensure_ubuntu_repository
            ;;
        debian)
            ensure_debian_repository
            ;;
    esac

    sudo apt-get update
}

package_exists() {
    apt-cache show "$1" >/dev/null 2>&1
}

available_versions() {
    local version
    apt-cache pkgnames php 2>/dev/null |
        sed -nE 's/^php([0-9]+\.[0-9]+)$/\1/p' |
        sort -Vru |
        while IFS= read -r version; do
            if php_version_supported "$version"; then
                printf '%s\n' "$version"
            fi
        done || true
}

installed_php_packages() {
    dpkg-query -W -f='${binary:Package}\t${db:Status-Abbrev}\n' 'php*' 2>/dev/null |
        awk '$2 ~ /^[ih]i/ {
            sub(/:.*/, "", $1)
            if ($1 ~ /^php[0-9]+\.[0-9]+($|-)/) {
                print $1
            }
        }' |
        sort -u || true
}

installed_versions() {
    installed_php_packages |
        sed -E 's/^php([0-9]+\.[0-9]+).*/\1/' |
        sort -Vru || true
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

select_php_version() {
    if [ -n "$REQUESTED_VERSION" ]; then
        VER="$REQUESTED_VERSION"
        return 0
    fi

    local versions=()

    if [ "$ACTION" = "install" ]; then
        mapfile -t versions < <(available_versions)
        [ "${#versions[@]}" -gt 0 ] || error_exit "No supported PHP versions are available from apt."
        VER="${versions[0]}"
        print_color green "Using the newest available PHP version: $VER"
        return 0
    fi

    [ -t 0 ] || error_exit "Pass a PHP version when running removal non-interactively."
    mapfile -t versions < <(installed_versions)
    [ "${#versions[@]}" -gt 0 ] || error_exit "No versioned PHP packages are installed."
    require_fzf
    VER="$(printf '%s\n' "${versions[@]}" | fzf --height=40% --reverse --prompt="Remove PHP version> " --header="Installed PHP versions" || true)"
    [ -n "$VER" ] || error_exit "Cancelled."
}

build_common_package_set() {
    local version="$1"
    local extension
    local package
    local skipped=()
    PHP_PACKAGES=()

    for extension in "${COMMON_EXTENSIONS[@]}"; do
        package="php$version-$extension"
        if package_exists "$package"; then
            PHP_PACKAGES+=("$package")
        else
            skipped+=("$package")
        fi
    done

    package_exists "php$version-cli" || error_exit "PHP $version is not available from apt."

    if [ "${#skipped[@]}" -gt 0 ]; then
        print_color yellow "Skipping unavailable PHP packages:"
        printf '  %s\n' "${skipped[@]}"
    fi
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

prepare_legacy_php_packages() {
    local held=()
    local additional=()
    mapfile -t held < <(apt-mark showhold 2>/dev/null | awk -v prefix="php$VER" '$0 == prefix || index($0, prefix "-") == 1' | sort -u)
    [ "${#held[@]}" -gt 0 ] || return 0

    print_color yellow "Removing legacy PHP package holds:"
    printf '  %s\n' "${held[@]}"
    unhold_packages "${held[@]}"

    mapfile -t additional < <(comm -23 <(printf '%s\n' "${held[@]}" | sort) <(printf '%s\n' "${PHP_PACKAGES[@]}" | sort))
    PHP_PACKAGES+=("${additional[@]}")
}

install_php() {
    ensure_php_repository
    select_php_version
    build_common_package_set "$VER"
    prepare_legacy_php_packages

    print_color green "Installing the common PHP $VER package set:"
    printf '  %s\n' "${PHP_PACKAGES[@]}"

    SUDO="sudo env DEBIAN_FRONTEND=noninteractive" pkg_install "${PHP_PACKAGES[@]}"
    set_php_alternatives "$VER"

    print_color green "PHP $VER and common extensions are installed."
}

confirm_removal() {
    [ -t 0 ] || return 0

    require_fzf
    local reply
    reply="$(printf 'No\nYes\n' | fzf --height=20% --reverse --prompt="Remove PHP $VER?> " || true)"
    [ "$reply" = "Yes" ] || error_exit "Cancelled."
}

remove_php() {
    select_php_version

    local installed=()
    local packages=()
    local package
    mapfile -t installed < <(installed_php_packages)

    for package in "${installed[@]}"; do
        if [[ "$package" == php"$VER" || "$package" == php"$VER"-* ]]; then
            packages+=("$package")
        fi
    done

    if [ "${#packages[@]}" -eq 0 ]; then
        print_color yellow "No PHP $VER packages are installed."
        return 0
    fi

    print_color yellow "Removing PHP $VER packages:"
    printf '  %s\n' "${packages[@]}"
    confirm_removal
    removePackage "${packages[@]}"
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
