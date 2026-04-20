#!/bin/bash
set -euo pipefail
source "$HOME/dotfiles/globals.sh"

VER="$(curl -fsSL 'https://go.dev/dl/?mode=json' |
    grep -m1 '"version"' | cut -d'"' -f4)"
VER="${VER#go}"

case "$ARCH" in
    x86_64) GO_ARCH="amd64" ;;
    aarch64) GO_ARCH="arm64" ;;
    *) GO_ARCH="amd64" ;;
esac
PLATFORM="linux-${GO_ARCH}"
LOC="/usr/local"
TARBALL="go${VER}.${PLATFORM}.tar.gz"

print_color green "Installing Go ${VER} (${PLATFORM})..."
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
curl -#fL "https://golang.org/dl/${TARBALL}" -o "$TMP/$TARBALL"
sudo rm -rf "$LOC/go"
sudo tar -xzf "$TMP/$TARBALL" -C "$LOC"
