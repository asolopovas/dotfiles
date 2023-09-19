#!/bin/bash

source $HOME/dotfiles/scripts/os.sh

NODE_VERSION=${NODE_VERSION:-18.18.0}
NVM_VERSION=${NVM_VERSION:-v0.39.5}
NVM_DIR="$HOME/.nvm"
FORCE=${FORCE:-false}

if [ "$FORCE" = "true" ]; then
    echo "Force install nodejs"
    rm -rf $NVM_DIR
fi

PROFILE=/dev/null curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash

if [ "$OS" = "alpine" ]; then
    sudo apk add --no-cache libstdc++;
    chmod +x $NVM_DIR/nvm.sh
    nvm_get_arch() { nvm_echo "x64-musl"; }
    sed -i '/nvm_get_arch() {/,/^}$/c\nvm_get_arch() { nvm_echo "x64-musl"; }' $HOME/.nvm/nvm.sh
fi

#
source "$NVM_DIR/nvm.sh"
nvm install $NODE_VERSION
npm -g install yarn
