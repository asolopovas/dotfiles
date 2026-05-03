#!/bin/bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
source "$DOTFILES_DIR/globals.sh"

PI_PACKAGES=(
    "npm:pi-claude-oauth-adapter"   # Anthropic OAuth / Claude Code compatibility adapter
    "npm:pi-subagents"              # Delegate tasks to subagents (chains, parallel, TUI)
    "npm:pi-mcp-adapter"            # MCP (Model Context Protocol) adapter
    "npm:pi-web-access"             # Web search, URL fetch, GitHub clone, PDF/YouTube/video analysis
    "npm:@plannotator/pi-extension" # Plannotator: interactive plan review with visual annotation
    "npm:@a5c-ai/babysitter-pi"     # Babysitter package (supervises agent runs)
)

MCP_CONFIG="$HOME/.config/mcp/mcp.json"

install_pi() {
    if cmd_exist pi && [ "${FORCE:-false}" != true ]; then
        print_color yellow "pi already installed: $(pi --version 2>/dev/null || echo unknown)"
        return 0
    fi

    if ! cmd_exist bun; then
        print_color red "bun is required (run scripts/inst/inst-bun.sh)"
        exit 1
    fi
    print_color green "Installing pi via bun..."
    bun install -g @mariozechner/pi-coding-agent
}

installed_packages() {
    pi list 2>/dev/null | awk '/^[[:space:]]+npm:/ {print $1}'
}

install_packages() {
    local installed
    installed=$(installed_packages)

    local pkg
    for pkg in "${PI_PACKAGES[@]}"; do
        if [ "${FORCE:-false}" != true ] && grep -Fxq "$pkg" <<<"$installed"; then
            print_color yellow "  $pkg already installed"
            continue
        fi
        print_color green "  installing $pkg"
        pi install "$pkg"
    done
}

ensure_context7() {
    mkdir -p "$(dirname "$MCP_CONFIG")"
    [ -f "$MCP_CONFIG" ] || echo '{"mcpServers":{}}' >"$MCP_CONFIG"

    if ! cmd_exist jq; then
        print_color red "jq is required"
        exit 1
    fi

    if jq -e '.mcpServers.context7' "$MCP_CONFIG" >/dev/null 2>&1 && [ "${FORCE:-false}" != true ]; then
        print_color yellow "context7 MCP already configured in $MCP_CONFIG"
        return 0
    fi

    local tmp
    tmp=$(mktemp)
    jq '.mcpServers.context7 = {
            "command": "npx",
            "args": ["-y", "@upstash/context7-mcp"]
        }' "$MCP_CONFIG" >"$tmp" && mv "$tmp" "$MCP_CONFIG"
    print_color green "context7 MCP added to $MCP_CONFIG"
}

main() {
    install_pi
    install_packages
    ensure_context7
    print_color green "pi setup complete."
}

main "$@"
