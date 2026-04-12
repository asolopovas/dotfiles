#!/bin/bash

VER="10.3.0"

source "$HOME/dotfiles/globals.sh"

if [ "${FORCE:-false}" != true ] && command -v fd &>/dev/null; then
    print_color green "fd $(fd --version) already installed — skipping"
    return 0 2>/dev/null || exit 0
fi

case "$ARCH" in
    x86_64)  ARCH_LABEL="x86_64-unknown-linux-gnu" ;;
    aarch64) ARCH_LABEL="aarch64-unknown-linux-gnu" ;;
    *)
        echo "Unsupported architecture for fd: $ARCH"
        return 1 2>/dev/null || exit 1
        ;;
esac

if [ "$OS" = "macos" ]; then
    brew install fd
    return 0 2>/dev/null || exit 0
fi

FILE="fd-v${VER}-${ARCH_LABEL}"
URL="https://github.com/sharkdp/fd/releases/download/v$VER/$FILE.tar.gz"

print_color green "Installing fd find for ${OS^} ($ARCH) from ${URL}..."
curl -fsSLO "$URL"
tar -xf "$FILE.tar.gz" -C . "$FILE/fd"
mkdir -p "$HOME/.local/bin"
mv "$FILE/fd" "$HOME/.local/bin"
rm -rf "$FILE" "$FILE.tar.gz"
