#!/bin/bash

INSTALL_ARCHIVE="nvim-linux-x86_64.tar.gz"
URL="https://github.com/neovim/neovim/releases/latest/download/$INSTALL_ARCHIVE"
SCRIPT_PATH="${BASH_SOURCE[0]}"
if command -v readlink >/dev/null 2>&1; then
    SCRIPT_PATH="$(readlink -f "$SCRIPT_PATH" 2>/dev/null || echo "$SCRIPT_PATH")"
fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

is_sourced() {
    [ "${BASH_SOURCE[0]}" != "$0" ]
}

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

run_installer() {
    local script_name=$1
    local script_path="$SCRIPT_DIR/inst-$script_name.sh"

    if [ -f "$script_path" ]; then
        source "$script_path"
        return 0
    fi

    return 1
}

ensure_nvim_config() {
    local nvim_config="$HOME/.config/nvim"
    local source_config="$DOTFILES_DIR/config/nvim"
    local resolved_target

    if [ -L "$nvim_config" ] && [ "$(readlink "$nvim_config")" = "$source_config" ]; then
        return
    fi
    if [ -L "$nvim_config" ]; then
        resolved_target="$(readlink -f "$nvim_config" 2>/dev/null || true)"
        if [ "$resolved_target" = "$source_config" ]; then
            return
        fi
    fi

    if [ -d "$source_config" ]; then
        mkdir -p "$HOME/.config"
        if [ -L "$nvim_config" ]; then
            rm -f "$nvim_config"
        elif [ -e "$nvim_config" ]; then
            rm -rf "$nvim_config"
        fi
        ln -sf "$source_config" "$nvim_config"
        return
    fi

    echo "Missing $source_config; skipping nvim config symlink."
}

ensure_node() {
    local volta_home=${VOLTA_HOME:-$HOME/.volta}

    if [ -d "$volta_home/bin" ]; then
        export VOLTA_HOME="$volta_home"
        export PATH="$VOLTA_HOME/bin:$PATH"
    fi

    if command -v node >/dev/null 2>&1; then
        return
    fi

    if [ -f "$SCRIPT_DIR/inst-node.sh" ]; then
        bash "$SCRIPT_DIR/inst-node.sh" || return 1
    else
        run_installer "node" || return 1
    fi

    if [ -d "$volta_home/bin" ]; then
        export VOLTA_HOME="$volta_home"
        export PATH="$VOLTA_HOME/bin:$PATH"
    fi

    if ! command -v node >/dev/null 2>&1; then
        echo "Node install failed or not on PATH. Check Volta logs in $volta_home/log."
        return 1
    fi
}

ensure_deno() {
    local deno_home=${DENO_INSTALL:-$HOME/.deno}

    if [ -d "$deno_home/bin" ]; then
        export PATH="$deno_home/bin:$PATH"
    fi

    if command -v deno >/dev/null 2>&1; then
        return
    fi

    run_installer "deno" || return 1

    if [ -d "$deno_home/bin" ]; then
        export PATH="$deno_home/bin:$PATH"
    fi

    if ! command -v deno >/dev/null 2>&1; then
        echo "Deno install failed or not on PATH. Check $deno_home/bin."
        return 1
    fi
}

install_user() {
    local dir="$HOME/.local"
    local bin="$dir/bin"
    mkdir -p "$bin"
    download_and_extract "$dir"
    mv "$dir/nvim-linux-x86_64" "$dir/nvim"
    link_binaries "$dir/nvim/bin/nvim" "$bin/nvim" "$bin/vim"
    ensure_nvim_config
    ensure_node || return 1
    ensure_deno || return 1
    "$dir/nvim/bin/nvim" --headless "+Lazy sync" +qa
}

install_root() {
    rm -rf /opt/nvim
    download_and_extract /opt
    mv /opt/nvim-linux-x86_64 /opt/nvim
    link_binaries "/opt/nvim/bin/nvim" "/usr/bin/nvim" "/usr/bin/vim"
    ensure_nvim_config
    ensure_node || return 1
    ensure_deno || return 1
    /opt/nvim/bin/nvim --headless "+Lazy sync" +qa
}

sync_existing() {
    local nvim_bin
    nvim_bin="$(command -v nvim 2>/dev/null || true)"
    if [ -z "$nvim_bin" ]; then
        return 1
    fi

    ensure_nvim_config
    ensure_node || return 1
    ensure_deno || return 1
    "$nvim_bin" --headless "+Lazy sync" +qa
}

main() {
    if command -v nvim >/dev/null 2>&1; then
        sync_existing
        return $?
    fi

    if [ "$(id -u)" -eq 0 ]; then
        install_root
    else
        install_user
    fi
}

main
status=$?
if is_sourced; then
    return $status
fi
exit $status
