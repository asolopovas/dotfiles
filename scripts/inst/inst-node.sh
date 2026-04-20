#!/bin/bash
set -euo pipefail
source "$HOME/dotfiles/globals.sh"

NODE_VERSION="${NODE_VERSION:-lts}"
VOLTA_HOME="${VOLTA_HOME:-$HOME/.volta}"

ensure_volta() {
    if cmd_exist volta; then return; fi

    if [ -x "$VOLTA_HOME/bin/volta" ]; then
        export VOLTA_HOME
        export PATH="$VOLTA_HOME/bin:$PATH"
        return
    fi

    print_color green "Installing Volta..."
    curl -fsSL https://get.volta.sh | bash
    export VOLTA_HOME
    export PATH="$VOLTA_HOME/bin:$PATH"
}

print_color green "Installing Node ($NODE_VERSION)..."
ensure_volta
volta install "node@${NODE_VERSION}"
