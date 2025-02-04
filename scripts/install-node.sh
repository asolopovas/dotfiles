#!/bin/bash

source $HOME/dotfiles/globals.sh

NODE_VERSION=${NODE_VERSION:-22.13.1}
NVM_VERSION=${NVM_VERSION:-v0.40.1}
NVM_DIR="$HOME/.nvm"
FORCE=${FORCE:-false}

print_color green "Installing Node Version: ${NODE_VERSION}"
curl https://get.volta.sh | bash
volta install node@${NODE_VERSION}
