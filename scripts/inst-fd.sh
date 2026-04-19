#!/bin/bash
set -euo pipefail
source "$HOME/dotfiles/globals.sh"

if [ "${FORCE:-false}" != true ] && command -v fd &>/dev/null; then
    print_color green "fd $(fd --version) already installed — skipping"
    return 0 2>/dev/null || exit 0
fi

if [ "$OS" = "macos" ]; then
    brew install fd
    return 0 2>/dev/null || exit 0
fi

case "$ARCH" in
    x86_64)  ARCH_LABEL="x86_64-unknown-linux-gnu" ;;
    aarch64) ARCH_LABEL="aarch64-unknown-linux-gnu" ;;
    *)
        echo "Unsupported architecture for fd: $ARCH" >&2
        return 1 2>/dev/null || exit 1
        ;;
esac

VER="$(gh_latest_release sharkdp/fd)"
FILE="fd-v${VER}-${ARCH_LABEL}"
URL="https://github.com/sharkdp/fd/releases/download/v${VER}/${FILE}.tar.gz"

print_color green "Installing fd ${VER} for ${OS} (${ARCH})..."
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
curl -fsSL "$URL" -o "$TMP/$FILE.tar.gz"
tar -xf "$TMP/$FILE.tar.gz" -C "$TMP" "$FILE/fd"
mkdir -p "$HOME/.local/bin"
mv "$TMP/$FILE/fd" "$HOME/.local/bin/"
