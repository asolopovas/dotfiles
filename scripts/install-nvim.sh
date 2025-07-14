#!/bin/bash

INSTALL_ARCHIVE="nvim-linux-x86_64.tar.gz"
URL="https://github.com/neovim/neovim/releases/latest/download/$INSTALL_ARCHIVE"

download_and_extract() {
    local target_dir=$1
    curl -L -o "$INSTALL_ARCHIVE" "$URL"
    tar -xzf "$INSTALL_ARCHIVE" -C "$target_dir"
    rm -f "$INSTALL_ARCHIVE"
}

link_binaries() {
    local nvim_bin=$1
    shift
    for link in "$@"; do
        ln -sf "$nvim_bin" "$link"
    done
}

install_user() {
    local dir="$HOME/.local"
    local bin="$dir/bin"
    mkdir -p "$bin"
    download_and_extract "$dir"
    mv "$dir/nvim-linux-x86_64" "$dir/nvim"
    link_binaries "$dir/nvim/bin/nvim" "$bin/nvim" "$bin/vim"
    "$dir/nvim/bin/nvim" --headless "+Lazy! sync" +qa
}

install_root() {
    rm -rf /opt/nvim
    download_and_extract /opt
    mv /opt/nvim-linux-x86_64 /opt/nvim
    link_binaries "/opt/nvim/bin/nvim" "/usr/bin/nvim" "/usr/bin/vim"
    /opt/nvim/bin/nvim --headless "+Lazy! sync" +qa
}

if command -v nvim >/dev/null 2>&1; then
    exit 0
fi

if [ "$(id -u)" -eq 0 ]; then
    install_root
else
    install_user
fi
