#!/bin/bash
set -eu

INSTALL_ARCHIVE="nvim-linux-x86_64.tar.gz"
URL="https://github.com/neovim/neovim/releases/latest/download/$INSTALL_ARCHIVE"

SCRIPT_PATH="${BASH_SOURCE[0]}"
if [ ! -e "$SCRIPT_PATH" ]; then
    script_lookup="$(command -v -- "$SCRIPT_PATH" 2>/dev/null || true)"
    if [ -n "$script_lookup" ]; then
        SCRIPT_PATH="$script_lookup"
    fi
fi
if command -v readlink >/dev/null 2>&1; then
    SCRIPT_PATH="$(readlink -f "$SCRIPT_PATH" 2>/dev/null || echo "$SCRIPT_PATH")"
fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

is_sourced() {
    [ "${BASH_SOURCE[0]}" != "$0" ]
}

ensure_path() {
    local dir=$1

    if [ -d "$dir" ]; then
        case ":$PATH:" in
            *":$dir:"*) ;;
            *) export PATH="$dir:$PATH" ;;
        esac
    fi
}

download_and_extract() {
    local target_dir=$1
    local tmp_dir

    tmp_dir="$(mktemp -d)"
    curl -fsSL -o "$tmp_dir/$INSTALL_ARCHIVE" "$URL"
    tar -xzf "$tmp_dir/$INSTALL_ARCHIVE" -C "$target_dir"
    rm -rf "$tmp_dir"
}

link_binaries() {
    local nvim_bin=$1
    shift

    for link in "$@"; do
        ln -sf "$nvim_bin" "$link"
    done
}

ensure_nvim_config() {
    local nvim_config="$HOME/.config/nvim"
    local source_config="$DOTFILES_DIR/.config/nvim"
    local resolved_target

    if [ -L "$nvim_config" ]; then
        if [ "$(readlink "$nvim_config")" = "$source_config" ]; then
            return
        fi
        resolved_target="$(readlink -f "$nvim_config" 2>/dev/null || true)"
        if [ "$resolved_target" = "$source_config" ]; then
            return
        fi
        echo "nvim config symlink points elsewhere; leaving untouched."
        return
    fi

    if [ -e "$nvim_config" ]; then
        echo "nvim config exists; leaving untouched."
        return
    fi

    if [ -d "$source_config" ]; then
        mkdir -p "$HOME/.config"
        ln -s "$source_config" "$nvim_config"
        return
    fi

    echo "Missing $source_config; skipping nvim config symlink."
}

ensure_node() {
    local volta_home=${VOLTA_HOME:-$HOME/.volta}

    ensure_path "$volta_home/bin"
    if command -v node >/dev/null 2>&1; then
        return
    fi

    if [ -f "$SCRIPT_DIR/inst-node.sh" ]; then
        bash "$SCRIPT_DIR/inst-node.sh" || return 1
    else
        echo "Missing $SCRIPT_DIR/inst-node.sh."
        return 1
    fi

    ensure_path "$volta_home/bin"
    if ! command -v node >/dev/null 2>&1; then
        echo "Node install failed or not on PATH. Check Volta logs in $volta_home/log."
        return 1
    fi
}

ensure_deno() {
    local deno_home=${DENO_INSTALL:-$HOME/.deno}

    ensure_path "$deno_home/bin"
    if command -v deno >/dev/null 2>&1; then
        return
    fi

    if [ -f "$SCRIPT_DIR/inst-deno.sh" ]; then
        bash "$SCRIPT_DIR/inst-deno.sh" || return 1
    else
        echo "Missing $SCRIPT_DIR/inst-deno.sh."
        return 1
    fi

    ensure_path "$deno_home/bin"
    if ! command -v deno >/dev/null 2>&1; then
        echo "Deno install failed or not on PATH. Check $deno_home/bin."
        return 1
    fi
}

is_managed_nvim() {
    local nvim_bin=$1
    local resolved

    if [ -z "$nvim_bin" ]; then
        return 1
    fi

    if [ "$nvim_bin" = "$HOME/.local/nvim/bin/nvim" ] || [ "$nvim_bin" = "/opt/nvim/bin/nvim" ]; then
        return 0
    fi

    if command -v readlink >/dev/null 2>&1; then
        resolved="$(readlink -f "$nvim_bin" 2>/dev/null || true)"
        if [ "$resolved" = "$HOME/.local/nvim/bin/nvim" ] || [ "$resolved" = "/opt/nvim/bin/nvim" ]; then
            return 0
        fi
    fi

    return 1
}

reset_install_dir() {
    local dir=$1

    if [ -L "$dir" ] || [ -f "$dir" ]; then
        rm -f "$dir"
    elif [ -d "$dir" ]; then
        rm -rf "$dir"
    fi
}

sync_plugins() {
    local nvim_bin=$1

    if ! "$nvim_bin" --headless \
        "+lua local ok,lazy=pcall(require,'lazy'); if ok then lazy.sync({wait=true}) end" \
        +qa; then
        echo "Lazy sync skipped (nvim startup failed)."
    fi
}

install_user() {
    local dir="$HOME/.local"
    local bin="$dir/bin"

    mkdir -p "$bin"
    download_and_extract "$dir"
    reset_install_dir "$dir/nvim"
    mv "$dir/nvim-linux-x86_64" "$dir/nvim"
    link_binaries "$dir/nvim/bin/nvim" "$bin/nvim" "$bin/vim"
    ensure_nvim_config
    ensure_node
    ensure_deno
    sync_plugins "$dir/nvim/bin/nvim"
}

install_root() {
    reset_install_dir /opt/nvim
    download_and_extract /opt
    mv /opt/nvim-linux-x86_64 /opt/nvim
    link_binaries "/opt/nvim/bin/nvim" "/usr/bin/nvim" "/usr/bin/vim"
    ensure_nvim_config
    ensure_node
    ensure_deno
    sync_plugins /opt/nvim/bin/nvim
}

sync_existing() {
    local nvim_bin=$1

    ensure_nvim_config
    ensure_node
    ensure_deno
    sync_plugins "$nvim_bin"
}

main() {
    local nvim_bin

    # Shared install: non-root with shared data + wrapper present — skip all installs
    # Config symlink is NOT created here; it was removed by plesk-install-nvim.sh
    # and cfg-default-dirs.sh skips it too when shared install is detected.
    if [ "$(id -u)" -ne 0 ] && [ -d "/opt/nvim-data/nvim/lazy" ] && [ -x "/usr/local/bin/nvim" ]; then
        mkdir -p "$HOME/.vim/undodir" "$HOME/.local/state/nvim"
        return
    fi

    if command -v nvim >/dev/null 2>&1; then
        nvim_bin="$(command -v nvim 2>/dev/null || true)"
        if is_managed_nvim "$nvim_bin"; then
            sync_existing "$nvim_bin"
            return
        fi
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
