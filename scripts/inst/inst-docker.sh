#!/bin/bash
set -euo pipefail
source "$HOME/dotfiles/globals.sh"

if [ "${FORCE:-false}" != true ] && cmd_exist docker; then
    print_color green "docker already installed — skipping"
    exit 0
fi

if [ "$OS" = "linuxmint" ]; then
    OS=ubuntu
    VERSION_CODENAME="jammy"
else
    . /etc/os-release 2>/dev/null || true
fi
VERSION_CODENAME="${VERSION_CODENAME:-stable}"

case "$OS" in
    ubuntu | debian) ;;
    *)
        print_color red "Unsupported OS: $OS"
        exit 1
        ;;
esac

print_color green "Installing Docker for $OS..."
sudo apt-get update -qq
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL "https://download.docker.com/linux/$OS/gpg" |
    sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS $VERSION_CODENAME stable" |
    sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

sudo apt-get update -qq
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
