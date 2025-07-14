#!/bin/bash

VER=${1:-"8.3"}

source $HOME/dotfiles/globals.sh

print_color green "Installing PHP Version: $VER for ${OS^} ...\n"

phpPackages=(
    "php$VER"
    "php$VER-bcmath"
    "php$VER-bz2"
    "php$VER-cli"
    "php$VER-common"
    "php$VER-curl"
    "php$VER-fpm"
    "php$VER-gd"
    "php$VER-imagick"
    # "php$VER-imap"
    # "php$VER-json"
    # "php$VER-litespeed"
    "php$VER-mbstring"
    # "php$VER-memcache"
    # "php$VER-memcached"
    "php$VER-mongodb"
    "php$VER-igbinary"
    "php$VER-mysql"
    "php$VER-pcov"
    "php$VER-pgsql"
    "php$VER-opcache"
    "php$VER-phpdbg"
    "php$VER-redis"
    "php$VER-sqlite3"
    "php$VER-xdebug"
    "php$VER-xml"
    "php$VER-yaml"
    "php$VER-zip"
)

packages=$(
    IFS=$'\n'
    echo "${phpPackages[*]}"
)

case "$2" in
uninstall)
    removePackage $packages
    sudo apt-mark unhold $packages
    ;;
*)
    sudo apt-mark unhold $packages
    installPackages $packages
    sudo apt-mark hold $packages
    ;;
esac
