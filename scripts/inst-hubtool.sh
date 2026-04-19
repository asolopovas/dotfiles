#!/bin/bash
set -euo pipefail
source "$HOME/dotfiles/globals.sh"

VERSION="$(gh_latest_release docker/hub-tool)"
DEST="$HOME/.local/bin"
URL="https://github.com/docker/hub-tool/releases/download/v${VERSION}/hub-tool-linux-amd64.tar.gz"

print_color green "Installing hub-tool ${VERSION}..."
mkdir -p "$DEST" "$HOME/tmp"
curl -#fsSL "$URL" -o "$HOME/tmp/hub-tool.tar.gz"
tar -xf "$HOME/tmp/hub-tool.tar.gz" -C "$HOME/tmp"
mv "$HOME/tmp/hub-tool/hub-tool" "$DEST/hub-tool"
chmod +x "$DEST/hub-tool"
rm -rf "$HOME/tmp/hub-tool" "$HOME/tmp/hub-tool.tar.gz"
