#!/bin/bash
set -euo pipefail
source "$HOME/dotfiles/globals.sh"

if [ "${FORCE:-false}" != true ] && cmd_exist cog; then
    print_color green "cog already installed — skipping"
    exit 0
fi

URL="https://github.com/replicate/cog/releases/latest/download/cog_$(uname -s)_$(uname -m)"
print_color green "Installing cog..."
sudo curl -fsSL "$URL" -o /usr/local/bin/cog
sudo chmod +x /usr/local/bin/cog
