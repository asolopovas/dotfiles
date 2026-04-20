#!/bin/bash
set -euo pipefail
source "$HOME/dotfiles/globals.sh"

if [ "${FORCE:-false}" != true ] && cmd_exist bun; then
    print_color green "bun $(bun --version) already installed — skipping"
    return 0 2>/dev/null || exit 0
fi

print_color green "Installing bun..."
curl -fsSL https://bun.com/install | bash
