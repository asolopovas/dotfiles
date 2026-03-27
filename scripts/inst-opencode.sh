#!/bin/bash

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
source "$DOTFILES_DIR/globals.sh"

OPENCODE_SRC="$DOTFILES_DIR/.config/opencode"
OPENCODE_DST="$HOME/.config/opencode"

# Files/dirs to symlink (Linux) or copy (Windows)
CONFIGS=(
    "config.json"
    "opencode.jsonc"
    "agents"
)

# Skills installed via bunx skills add (owner/repo format)
# Browse available skills at https://skills.sh
SKILLS=(
    "github/awesome-copilot@chrome-devtools"
    "microsoft/playwright-cli@playwright-cli"
    "davila7/claude-code-templates@Error Resolver"
    "affaan-m/everything-claude-code@laravel-security"
    "affaan-m/everything-claude-code@laravel-patterns"
    "affaan-m/everything-claude-code@laravel-tdd"
    "affaan-m/everything-claude-code@verification-loop"
    "affaan-m/everything-claude-code@golang-testing"
    "affaan-m/everything-claude-code@golang-patterns"
    "affaan-m/everything-claude-code@database-migrations"
    "sickn33/antigravity-awesome-skills@bash-scripting"
    "sickn33/antigravity-awesome-skills@progressive-web-app"
    "sickn33/antigravity-awesome-skills@wordpress-plugin-development"
    "sickn33/antigravity-awesome-skills@wordpress-penetration-testing"
    "sickn33/antigravity-awesome-skills@wordpress"
    "sickn33/antigravity-awesome-skills@wordpress-woocommerce-development"
    "sickn33/antigravity-awesome-skills@wordpress-theme-development"
    "affaan-m/everything-claude-code@docker-patterns"
)

# Windows-only skills
SKILLS_WINDOWS=(
    "sickn33/antigravity-awesome-skills@powershell-windows"
)

install_opencode() {
    if cmd_exist opencode; then
        print_color yellow "OpenCode already installed: $(opencode --version 2>/dev/null || echo 'unknown version')"
    else
        print_color green "Installing OpenCode..."
        curl -fsSL https://opencode.ai/install | bash
    fi
}

install_skills_linux() {
    if ! cmd_exist bunx; then
        print_color yellow "bunx not found, skipping Linux skills install"
        return 0
    fi

    print_color green "Installing OpenCode skills (Linux)..."
    for skill in "${SKILLS[@]}"; do
        print_color green "  skill: $skill"
        bunx skills add "$skill" -g -a opencode -y 2>/dev/null || {
            print_color yellow "  failed to install: $skill"
        }
    done
}

install_skills_windows() {
    if ! grep -qi microsoft /proc/version 2>/dev/null; then
        return 0
    fi

    if ! cmd.exe /C "where bunx" >/dev/null 2>&1; then
        print_color yellow "Windows bunx not found, skipping Windows skills install"
        return 0
    fi

    print_color green "Installing OpenCode skills (Windows)..."
    for skill in "${SKILLS[@]}" "${SKILLS_WINDOWS[@]}"; do
        print_color green "  skill: $skill"
        cmd.exe /C "bunx skills add $skill -g -a opencode -y" 2>/dev/null || {
            print_color yellow "  failed to install: $skill"
        }
    done
}

install_skills() {
    install_skills_linux
    install_skills_windows
}

link_config() {
    local src="$1" dst="$2"

    if [ -L "$dst" ]; then
        local target
        target="$(readlink "$dst" 2>/dev/null || true)"
        if [ "$target" = "$src" ]; then
            return 0
        fi
        rm -f "$dst"
    elif [ -e "$dst" ]; then
        rm -rf "$dst"
    fi

    mkdir -p "$(dirname "$dst")"
    ln -sf "$src" "$dst"
    print_color green "  symlink: $dst -> $src"
}

copy_config() {
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

setup_linux() {
    print_color green "Setting up OpenCode config (Linux)..."
    mkdir -p "$OPENCODE_DST"

    for item in "${CONFIGS[@]}"; do
        link_config "$OPENCODE_SRC/$item" "$OPENCODE_DST/$item"
    done
}

setup_windows() {
    # Only run under WSL
    if ! grep -qi microsoft /proc/version 2>/dev/null; then
        return 0
    fi

    local win_home
    win_home="$(wslpath "$(cmd.exe /C 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')")" || return 0

    if [ ! -d "$win_home" ]; then
        print_color yellow "Windows home not found: $win_home"
        return 0
    fi

    local win_dst="$win_home/.config/opencode"
    print_color green "Setting up OpenCode config (Windows: $win_dst)..."
    mkdir -p "$win_dst"

    for item in "${CONFIGS[@]}"; do
        copy_config "$OPENCODE_SRC/$item" "$win_dst/$item"
    done
}

install_opencode
setup_linux
setup_windows
install_skills

print_color green "OpenCode setup complete!"
