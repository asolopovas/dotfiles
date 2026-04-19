#!/usr/bin/env bash
set -euo pipefail

source "$HOME/dotfiles/globals.sh"

VER="${1:-8.3}"
ACTION="${2:-install}"

EXTENSIONS=(
    bcmath bz2 cli common curl fpm gd igbinary imagick mbstring
    mongodb mysql opcache pcov pgsql phpdbg redis sqlite3 xdebug
    xml yaml zip
)

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
                sudo apt install -y lsb-release ca-certificates curl
                sudo curl -sSLo /etc/apt/trusted.gpg.d/sury-php.gpg https://packages.sury.org/php/apt.gpg
                echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" |
                    sudo tee /etc/apt/sources.list.d/sury-php.list >/dev/null
                sudo apt update
            fi
            ;;
    esac
}

available_packages() {
    local pkgs=("php$VER")
    for ext in "${EXTENSIONS[@]}"; do
        pkgs+=("php$VER-$ext")
    done

    local available=()
    for p in "${pkgs[@]}"; do
        if apt-cache show "$p" >/dev/null 2>&1; then
            available+=("$p")
        else
            print_color yellow "Skipping unavailable package: $p"
        fi
    done
    printf '%s\n' "${available[@]}"
}

main() {
    print_color green "PHP $VER — action: $ACTION (${OS^})"
    ensure_ppa

    mapfile -t packages < <(available_packages)
    if [ "${#packages[@]}" -eq 0 ]; then
        print_color red "No PHP $VER packages available for this system."
        exit 1
    fi

    case "$ACTION" in
        uninstall | remove)
            unhold_packages "${packages[@]}" || true
            removePackage "${packages[@]}"
            ;;
        install | *)
            unhold_packages "${packages[@]}" || true
            installPackages "${packages[@]}"
            hold_packages "${packages[@]}"
            ;;
    esac
}

main "$@"
