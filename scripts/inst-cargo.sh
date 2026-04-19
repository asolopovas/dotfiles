#!/bin/bash
set -euo pipefail
source "$HOME/dotfiles/globals.sh"

if [ "${FORCE:-false}" != true ] && cmd_exist cargo; then
    print_color green "cargo already installed — skipping"
    return 0 2>/dev/null || exit 0
fi

print_color green "Installing rustup/cargo..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
