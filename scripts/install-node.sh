#!/bin/bash

OS=$(awk -F= '/^ID=/ {gsub(/"/, "", $2); print tolower($2)}' /etc/os-release)
NODE_VERSION=${NODE_VERSION:-18.16.1}
FORCE=${FORCE:-false}
NVM_VERSION=${NVM_VERSION:-v0.39.3}
NVM_DIR="$HOME/.nvm"

if [ "$FORCE" = "true" ]; then
    echo "Force install nodejs"
    rm -rf ~/.nvm
fi


PROFILE=/dev/null curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash

if [ "$OS" = "alpine" ]; then
    sudo apk add --no-cache libstdc++;
    chmod +x $HOME/.nvm/nvm.sh
    nvm_get_arch() { nvm_echo "x64-musl"; }
    sed -i '/nvm_get_arch() {/,/^}$/c\nvm_get_arch() { nvm_echo "x64-musl"; }' $HOME/.nvm/nvm.sh
fi

# 
source "$HOME/.nvm/nvm.sh"
nvm install $NODE_VERSION
npm -g install yarn
