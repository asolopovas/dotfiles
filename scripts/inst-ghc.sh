#!/bin/bash
set -euo pipefail
source "$HOME/dotfiles/globals.sh"

if [ "${FORCE:-false}" != true ] && cmd_exist ghc; then
    print_color green "ghc already installed — skipping"
    exit 0
fi

print_color green "Installing GHC and build deps..."
sudo add-apt-repository -y ppa:hvr/ghc
sudo apt-get update -y
installPackages build-essential libgmp-dev software-properties-common ghc
