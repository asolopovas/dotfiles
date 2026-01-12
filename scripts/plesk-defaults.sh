#!/bin/bash

NODE_VER=${1:-23}
PHP_VER=${2:-8.3}

NODE_BIN_DIR="/opt/plesk/node/${NODE_VER}/bin"
PHP_BIN_DIR="/opt/plesk/php/${PHP_VER}/bin"

DEST_DIR="$HOME/.local/bin"

[ ! -d "$DEST_DIR" ] && mkdir -p "$DEST_DIR"

create_symlinks() {
    local src_dir="$1"
    local dest_dir="$2"

    if [ -d "$src_dir" ]; then
        for file in "$src_dir"/*; do
            if [ -f "$file" ] && [ ! -e "$dest_dir/$(basename "$file")" ]; then
                ln -s "$file" "$dest_dir/"
                echo "Linked $(basename "$file")"
            fi
        done
    else
        echo "Warning: Directory $src_dir does not exist."
    fi
}

# Create symlinks for Node.js
create_symlinks "$NODE_BIN_DIR" "$DEST_DIR"

# Create symlinks for PHP
create_symlinks "$PHP_BIN_DIR" "$DEST_DIR"

echo "Symlinks created in $DEST_DIR."
