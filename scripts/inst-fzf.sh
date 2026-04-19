#!/bin/bash
set -euo pipefail
source "$HOME/dotfiles/globals.sh"

FORCE=${1:-${FORCE:-false}}

if [ "$FORCE" = true ]; then
    rm -f "$HOME/.local/bin/fzf"
fi

if [ -f "$HOME/.local/bin/fzf" ] || { [ "$FORCE" != true ] && command -v fzf &>/dev/null; }; then
    return 0 2>/dev/null || exit 0
fi

case "$(uname -s)" in
    Darwin) PLATFORM="darwin" ;;
    *) PLATFORM="linux" ;;
esac

case "$ARCH" in
    x86_64) FZF_ARCH="amd64" ;;
    aarch64) FZF_ARCH="arm64" ;;
    *) FZF_ARCH="amd64" ;;
esac

VER="$(gh_latest_release junegunn/fzf)"
TARBALL="fzf-$VER-${PLATFORM}_${FZF_ARCH}.tar.gz"

print_color green "Installing fzf ${VER}..."
mkdir -p "$HOME/.local/bin"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
curl -fsSL "https://github.com/junegunn/fzf/releases/download/$VER/$TARBALL" -o "$TMP/$TARBALL"
tar -xf "$TMP/$TARBALL" -C "$TMP"
mv "$TMP/fzf" "$HOME/.local/bin/"
