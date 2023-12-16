#!/bin/bash

source $HOME/dotfiles/globals.sh

NODE_VERSION=${NODE_VERSION:-18.18.2}
NVM_VERSION=${NVM_VERSION:-v0.39.7}
NVM_DIR="$HOME/.nvm"
FORCE=${FORCE:-false}

print_color green "Installing Node Version: ${NODE_VERSION}"

if [ "$FORCE" = "true" ]; then
    print_color red "FORCE: Enabled - removing $NVM_DIR"
    rm -rf $NVM_DIR
fi

PROFILE=/dev/null bash -c "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash"

if [ -f "$NVM_DIR/nvm.sh" ]; then
    chmod +x $NVM_DIR/nvm.sh
    source "$NVM_DIR/nvm.sh"
    nvm install $NODE_VERSION

    npm -g install yarn pnpm
else
    print_color red "Node Install Failed"
fi
