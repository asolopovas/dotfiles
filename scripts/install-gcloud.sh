#!/bin/sh

VER="451.0.0"
ARCH="x86_64"
NAME="google-cloud-cli-${VER}-linux-${ARCH}.tar.gz"
INSTALL_DIR="/var/opt/google"
INSTALL_FILE="$INSTALL_DIR/google-cloud-sdk/install.sh"

[ ! -d "$INSTALL_DIR" ] && mkdir -p "$INSTALL_DIR"

curl -fSL#O "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/$NAME"
sudo tar -zxf "$NAME" -C "$INSTALL_DIR"

if [ -f "$INSTALL_FILE" ]; then
    sudo "$INSTALL_FILE"
else
    echo "Error: install.sh script not found."
fi

rm -rf "$NAME"
