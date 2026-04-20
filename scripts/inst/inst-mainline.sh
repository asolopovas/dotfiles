#!/bin/bash
set -euo pipefail
source "$HOME/dotfiles/globals.sh"

if [ "${FORCE:-false}" != true ] && cmd_exist mainline; then
    print_color green "mainline already installed — skipping"
    exit 0
fi

print_color green "Installing mainline kernel manager..."
export DEBIAN_FRONTEND=noninteractive
sudo add-apt-repository -y ppa:cappelikan/ppa
sudo apt-get update -q
sudo apt-get install -y -q mainline
