#!/bin/bash

[ ! -z $1 ] && ver=$1

source $HOME/dotfiles/globals.sh

print_color green "PHP install helper script in ${OS^} for $ver \n"

phpPackages=(
    "php$ver"
    "php$ver-bcmath"
    "php$ver-bz2"
    "php$ver-cli"
    "php$ver-common"
    "php$ver-curl"
    # "php$ver-fpm"
    "php$ver-gd"
    "php$ver-imagick"
    # "php$ver-imap"
    "php-json"
    # "php$ver-litespeed"
    "php$ver-mbstring"
    # "php$ver-memcache"
    # "php$ver-memcached"
    "php$ver-mongodb"
    "php$ver-mysql"
    "php$ver-pcov"
    "php$ver-pgsql"
    "php$ver-redis"
    "php$ver-sqlite3"
    "php$ver-xdebug"
    "php$ver-xml"
    "php$ver-yaml"
    "php$ver-zip"
)

packages=$(
    IFS=$'\n'
    echo "${phpPackages[*]}"
)

case "$1" in
uninstall)
    removePackage $packages
    ;;
*)
    installPackages $packages
    ;;
esac

