#!/bin/bash

VER="1.10.1"
ARCH="x86_64"
URL="https://github.com/cryptomator/cryptomator/releases/download/${VER}/cryptomator-${VER}-${ARCH}.AppImage"
DEST="$HOME/.local/bin/cryptomator"

curl -L "$URL" -o "$DEST"
chmod +x "$DEST"

mkdir -p "$HOME/.local/share/applications"
echo "[Desktop Entry]
Type=Application
Name=Cryptomator
Exec=$DEST
Icon=application-x-executable
Categories=Utility;" > "$HOME/.local/share/applications/cryptomator.desktop"
