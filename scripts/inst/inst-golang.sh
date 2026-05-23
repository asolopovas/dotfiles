#!/bin/bash
set -euo pipefail
source "$HOME/dotfiles/globals.sh"

[ "$OS" = macos ] && GO_OS=darwin || GO_OS=linux
case "$ARCH" in
    x86_64) GO_ARCH=amd64 ;;
    aarch64) GO_ARCH=arm64 ;;
    *)
        echo "Unsupported Go arch: $ARCH" >&2
        exit 1
        ;;
esac
TARGET="$GO_OS-$GO_ARCH"

VER="$(curl -fsSL https://go.dev/VERSION?m=text | head -1)"
TARBALL="$VER.$TARGET.tar.gz"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

print_color green "Installing $VER ($TARGET)..."
curl -#fL "https://go.dev/dl/$TARBALL" -o "$TMP/$TARBALL"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "$TMP/$TARBALL"
/usr/local/go/bin/go version
