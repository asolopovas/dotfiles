#!/bin/bash
set -euo pipefail
source "$HOME/dotfiles/globals.sh"

# Resolve latest bash tarball from GNU FTP
LATEST="$(curl -fsSL https://ftp.gnu.org/gnu/bash/ |
    grep -oE 'bash-[0-9]+\.[0-9]+(\.[0-9]+)?\.tar\.gz' |
    sort -V | tail -1)"
[ -n "$LATEST" ] || {
    echo "Failed to resolve latest bash version" >&2
    exit 1
}

VER="${LATEST#bash-}"
VER="${VER%.tar.gz}"

if command -v dnf &>/dev/null; then
    sudo dnf install -y gcc make ncurses-devel
elif command -v apt-get &>/dev/null; then
    sudo apt-get install -y build-essential libncurses-dev
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"
echo "Building bash ${VER}..."
curl -fsSLO "https://ftp.gnu.org/gnu/bash/${LATEST}"
tar xf "$LATEST"
cd "bash-${VER}"
./configure --prefix=/usr
make -j"$(nproc)"
sudo make install

bash --version
read -rp "Set as default shell? (y/N): " choice
[[ $choice == y || $choice == Y ]] && chsh -s /usr/bin/bash
