#!/bin/bash

source $HOME/dotfiles/globals.sh

NODE_VERSION=${NODE_VERSION:-22.16.0}

print_color green "Installing Node Version: ${NODE_VERSION}"
curl https://get.volta.sh | bash
volta install node@${NODE_VERSION}
