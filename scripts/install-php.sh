#!/bin/bash

# Default PHP version and fallback to user-provided version
VER=${1:-"8.3"}
ACTION=${2:-"install"} # Default action is "install"

# If the first argument is "list", set ACTION to "list" and ignore VER
if [[ "$1" == "list" ]]; then
    ACTION="list"
    VER="" # Clear VER since it's not needed for the "list" action
fi

# Source global settings (validate the file exists)
if [[ -f "$HOME/dotfiles/globals.sh" ]]; then
    source "$HOME/dotfiles/globals.sh"
else
    echo "Error: globals.sh not found in $HOME/dotfiles"
    exit 1
fi

# Only print the "Processing PHP Version" message if VER is not empty
if [[ -n "$VER" ]]; then
    print_color green "Processing PHP Version: $VER for ${OS^}...\n"
fi

# Function to validate the PHP version format (basic check)
validate_php_version() {
    if ! [[ "$VER" =~ ^[0-9]+\.[0-9]+$ ]]; then
        echo "Error: Invalid PHP version format. Expected 'X.Y' (e.g., 8.3)."
        exit 1
    fi
}

# Define an array of PHP packages
phpPackages=(
    "php$VER"
    "php$VER-bcmath"
    "php$VER-bz2"
    "php$VER-cli"
    "php$VER-common"
    "php$VER-curl"
    "php$VER-fpm"
    "php$VER-gd"
    "php$VER-igbinary"
    "php$VER-imagick"
    "php$VER-mbstring"
    "php$VER-mongodb"
    "php$VER-mysql"
    "php$VER-opcache"
    "php$VER-pcov"
    "php$VER-pgsql"
    "php$VER-phpdbg"
    "php$VER-readline"
    "php$VER-redis"
    "php$VER-sqlite3"
    "php$VER-xdebug"
    "php$VER-xml"
    "php$VER-yaml"
    "php$VER-zip"
)

# Convert the array to a space-separated list
packages=$(IFS=' '; echo "${phpPackages[*]}")

# Function to list installed PHP versions and packages
list_installed_php() {
    print_color yellow "Listing all installed PHP versions and related packages..."
    dpkg -l | grep -E '^ii.*php[0-9]+\.[0-9]+' | awk '{print $2}' | sort
    print_color green "End of installed PHP versions and packages list."
}

# Function to unhold packages (only if they are held)
unhold_packages() {
    for pkg in $packages; do
        if dpkg-query -W -f='${Status}\n' "$pkg" 2>/dev/null | grep -q "hold"; then
            sudo apt-mark unhold "$pkg"
        fi
    done
}

# Function to remove all PHP packages for a specific version
remove_php_packages() {
    print_color yellow "Removing PHP Version: $VER..."
    for pkg in $packages; do
        if dpkg-query -W -f='${Status}\n' "$pkg" 2>/dev/null | grep -q "installed"; then
            sudo apt-get remove --purge -y "$pkg"
        fi
    done
    print_color green "PHP Version $VER removed successfully."
}

# Main case to handle actions: install, uninstall, or list
case "$ACTION" in
    uninstall)
        validate_php_version
        remove_php_packages
        unhold_packages
        ;;
    install)
        validate_php_version
        print_color yellow "Installing PHP Version: $VER..."
        unhold_packages
        installPackages $packages || { echo "Failed to install packages"; exit 1; }
        sudo apt-mark hold $packages
        print_color green "PHP Version $VER installed and held successfully."
        ;;
    list)
        list_installed_php
        ;;
    *)
        echo "Error: Unsupported action '$ACTION'. Use 'install', 'uninstall', or 'list'."
        exit 1
        ;;
esac

# Only print the "Operation completed" message if VER is not empty
if [[ -n "$VER" ]]; then
    print_color green "Operation completed for PHP Version: $VER."
fi
