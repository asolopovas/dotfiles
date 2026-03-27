#!/bin/bash
# Path management -- add2path is a convenience wrapper around the same logic
# in globals.sh:add_paths_from_file (kept for direct use and backward compat).

add2path() {
    local full_path
    if [[ $1 == /* ]]; then
        full_path="$1"
    else
        full_path="$HOME/$1"
    fi

    if [ -d "$full_path" ] && [[ ":$PATH:" != *":$full_path:"* ]]; then
        export PATH="$full_path:$PATH"
    fi
}

while read -r line; do
    add2path "$line"
done <"$HOME/dotfiles/.paths"
