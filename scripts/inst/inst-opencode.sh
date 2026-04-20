#!/bin/bash

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
source "$DOTFILES_DIR/globals.sh"

OPENCODE_SRC="$DOTFILES_DIR/.config/opencode"

install_opencode() {
    if cmd_exist opencode; then
        print_color yellow "OpenCode already installed: $(opencode --version 2>/dev/null || echo 'unknown version')"
    else
        print_color green "Installing OpenCode..."
        curl -fsSL https://opencode.ai/install | bash
    fi
}

copy_config_windows() {
    local src="$1" dst="$2"

    mkdir -p "$(dirname "$dst")"
    if [ -d "$src" ]; then
        rm -rf "$dst"
        cp -r "$src" "$dst"
    else
        cp -f "$src" "$dst"
    fi
    print_color green "  copied: $src -> $dst"
}

setup_windows() {
    grep -qi microsoft /proc/version 2>/dev/null || return 0

    local win_home
    win_home="$(wslpath "$(cmd.exe /C 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')")" || return 0

    if [ ! -d "$win_home" ]; then
        print_color yellow "Windows home not found: $win_home"
        return 0
    fi

    local win_dst="$win_home/.config/opencode"
    print_color green "Setting up OpenCode config (Windows: $win_dst)..."
    mkdir -p "$win_dst"
    copy_config_windows "$OPENCODE_SRC/opencode.jsonc" "$win_dst/opencode.jsonc"
}

setup_shared_plesk() {
    [[ $EUID -eq 0 ]] || return 0
    command -v plesk >/dev/null 2>&1 || return 0

    local plesk_init="$DOTFILES_DIR/scripts/plesk-init.sh"
    [[ -x "$plesk_init" ]] || return 0

    print_color green "Plesk detected — propagating to shared locations..."
    "$plesk_init" opencode
}

install_opencode

SYNC_TARGETS=opencode "$DOTFILES_DIR/scripts/sync-ai.sh" config

setup_windows
setup_shared_plesk

print_color green "OpenCode setup complete!"
print_color green "Run 'sync-ai.sh' to install skills and MCP servers."
