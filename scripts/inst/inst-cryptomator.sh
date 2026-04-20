#!/bin/bash
set -euo pipefail
source "$HOME/dotfiles/globals.sh"

VER="$(gh_latest_release cryptomator/cryptomator)"
ARCH_LABEL="x86_64"
URL="https://github.com/cryptomator/cryptomator/releases/download/${VER}/cryptomator-${VER}-${ARCH_LABEL}.AppImage"
DEST="$HOME/.local/bin/cryptomator"

print_color green "Installing Cryptomator ${VER}..."
mkdir -p "$(dirname "$DEST")" "$HOME/.local/share/applications"
curl -fsSL "$URL" -o "$DEST"
chmod +x "$DEST"

cat >"$HOME/.local/share/applications/cryptomator.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Cryptomator
Exec=$DEST
Icon=application-x-executable
Categories=Utility;
EOF
