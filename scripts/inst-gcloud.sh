#!/bin/bash
set -euo pipefail
source "$HOME/dotfiles/globals.sh"

if [ "${FORCE:-false}" != true ] && cmd_exist gcloud; then
    print_color green "gcloud already installed — skipping"
    exit 0
fi

case "$ARCH" in
    x86_64) GC_ARCH="x86_64" ;;
    aarch64) GC_ARCH="arm" ;;
    *) GC_ARCH="x86_64" ;;
esac

NAME="google-cloud-cli-linux-${GC_ARCH}.tar.gz"
URL="https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/$NAME"
INSTALL_DIR="/var/opt/google"

print_color green "Installing Google Cloud SDK..."
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
curl -fL# "$URL" -o "$TMP/$NAME"

sudo mkdir -p "$INSTALL_DIR"
sudo tar -xzf "$TMP/$NAME" -C "$INSTALL_DIR"
sudo "$INSTALL_DIR/google-cloud-sdk/install.sh"
