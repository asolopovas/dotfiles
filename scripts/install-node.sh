#!/bin/bash

source $HOME/dotfiles/globals.sh

NODE_VERSION=${NODE_VERSION:-18.18.0}
NVM_VERSION=${NVM_VERSION:-v0.39.5}
NVM_DIR="$HOME/.nvm"
FORCE=${FORCE:-false}

print_color green "Installing Node Version: ${NODE_VERSION}"

if [ "$FORCE" = "true" ]; then
    print_color red "FORCE: Enabled - removing $NVM_DIR"
    rm -rf $NVM_DIR
fi

PROFILE=/dev/null bash -c "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash"

if [ "$OS" = "alpine" ]; then
    chmod +x $NVM_DIR/nvm.sh
    sed -i '/nvm_get_arch() {/,/^}$/c\nvm_get_arch() { nvm_echo "x64-musl"; }' $NVM_DIR/nvm.sh
fi

source "$NVM_DIR/nvm.sh"
nvm install $NODE_VERSION

npm -g install yarn
