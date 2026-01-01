#!/bin/bash

source $HOME/dotfiles/globals.sh

NODE_VERSION=${NODE_VERSION:-24.12.0}
VOLTA_HOME=${VOLTA_HOME:-$HOME/.volta}

ensure_volta() {
    if command -v volta >/dev/null 2>&1; then
        return
    fi

    if [ -x "$VOLTA_HOME/bin/volta" ]; then
        export VOLTA_HOME
        export PATH="$VOLTA_HOME/bin:$PATH"
        return
    fi

    print_color green "Installing Volta..."
    curl https://get.volta.sh | bash
    export VOLTA_HOME
    export PATH="$VOLTA_HOME/bin:$PATH"
}

print_color green "Installing Node Version: ${NODE_VERSION}"
ensure_volta
volta install "node@${NODE_VERSION}"
