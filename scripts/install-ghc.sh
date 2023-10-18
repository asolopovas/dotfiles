#!/bin/bash


if [ "$EUID" -ne 0 ]; then
    echo "Requesting elevated privileges..."
    sudo "$0" "$@"   # Run the script as root
    exit $?
fi

apt-get update
apt-get upgrade -y
apt-get install -y build-essential libgmp-dev
apt-get install -y software-properties-common
add-apt-repository -y ppa:hvr/ghc
apt-get update
apt-get install -y ghc
ghc --version
