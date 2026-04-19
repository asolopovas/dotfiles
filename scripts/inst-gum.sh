#!/bin/bash
set -euo pipefail
source "$HOME/dotfiles/globals.sh"

if [ "${FORCE:-false}" != true ] && cmd_exist gum; then
    print_color green "gum already installed — skipping"
    exit 0
fi

print_color green "Installing gum..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" \
    | sudo tee /etc/apt/sources.list.d/charm.list >/dev/null
sudo apt update
sudo apt install -y gum
