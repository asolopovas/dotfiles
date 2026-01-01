#!/bin/bash

source $HOME/dotfiles/globals.sh

if [ "$OS" == "linuxmint" ]; then
    OS=ubuntu
    VERSION_CODENAME=jammy
fi

# Common Installation steps
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings

case "$OS" in
ubuntu | debian)
    GPG_URL="https://download.docker.com/linux/$OS/gpg"
    REPO_URL="https://download.docker.com/linux/$OS"
    ;;
*)
    echo "Unsupported OS."
    exit 1
    ;;
esac

curl -fsSL $GPG_URL | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add the repository to Apt sources:
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] $REPO_URL $VERSION_CODENAME stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
