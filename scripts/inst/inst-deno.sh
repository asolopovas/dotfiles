#!/bin/bash
set -euo pipefail
source "$HOME/dotfiles/globals.sh"

if [ "${FORCE:-false}" != true ] && cmd_exist deno; then
    print_color green "deno $(deno --version | head -1) already installed — skipping"
    return 0 2>/dev/null || exit 0
fi

print_color green "Installing deno..."
curl -fsSL https://deno.land/install.sh | sh -s -- -y --no-modify-path
