#!/bin/bash

FORCE=${1:-${FORCE:-false}}
VER="0.42.0"

if [ "$FORCE" = true ]; then
    rm -f "$HOME/.local/bin/fzf"
fi

if [ -f "$HOME/.local/bin/fzf" ] || { [ "$FORCE" != true ] && command -v fzf &>/dev/null; }; then
    return 0 2>/dev/null || exit 0
fi

case "$(uname -s)" in
    Darwin) PLATFORM="darwin" ;;
    *)      PLATFORM="linux" ;;
esac

case "$(uname -m)" in
    x86_64|amd64)  FZF_ARCH="amd64" ;;
    aarch64|arm64) FZF_ARCH="arm64" ;;
    *)             FZF_ARCH="amd64" ;;
esac

print_color green "INSTALLING FZF..."
curl -fsSLO "https://github.com/junegunn/fzf/releases/download/$VER/fzf-$VER-${PLATFORM}_${FZF_ARCH}.tar.gz"
tar -xf "fzf-$VER-${PLATFORM}_${FZF_ARCH}.tar.gz"
mkdir -p "$HOME/.local/bin"
mv fzf "$HOME/.local/bin"
rm -f "fzf-$VER-${PLATFORM}_${FZF_ARCH}.tar.gz"
