#!/bin/sh

ARCH="x86_64"
NAME="google-cloud-cli-linux-${ARCH}.tar.gz"
URL="https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/$NAME"
INSTALL_DIR="/var/opt/google"
INSTALL_FILE="$INSTALL_DIR/google-cloud-sdk/install.sh"

TMP_DIR=$(mktemp -d) || { echo "Error: could not create temp dir"; exit 1; }
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

[ ! -d "$INSTALL_DIR" ] && sudo mkdir -p "$INSTALL_DIR"

if ! curl -fSL#o "$TMP_DIR/$NAME" "$URL"; then
    echo "Error: could not download latest gcloud CLI from $URL"
    exit 1
fi

sudo tar -zxf "$TMP_DIR/$NAME" -C "$INSTALL_DIR"

if [ -f "$INSTALL_FILE" ]; then
    sudo "$INSTALL_FILE"
else
    echo "Error: install.sh script not found."
fi
