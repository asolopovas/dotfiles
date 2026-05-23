#!/bin/bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
source "$DOTFILES_DIR/globals.sh"

PI_PACKAGES=(
    "npm:pi-claude-oauth-adapter"
    "npm:pi-subagents"
    "npm:pi-mcp-adapter"
    "npm:pi-web-access"
    "npm:pi-lens"
)

PI_NPM_PACKAGES=(
    "@earendil-works/pi-coding-agent@latest"
    "@earendil-works/pi-agent-core@latest"
    "@earendil-works/pi-ai@latest"
    "@earendil-works/pi-tui@latest"
)

MCP_CONFIG="$HOME/.config/mcp/mcp.json"
OLD_BUN_PI_PACKAGE="@mariozechner/pi-coding-agent"

install_pi() {
    if ! cmd_exist npm; then
        print_color red "npm is required (install Node.js/Volta first)"
        exit 1
    fi

    if cmd_exist bun; then
        bun remove -g "$OLD_BUN_PI_PACKAGE" >/dev/null 2>&1 || true
    fi

    print_color green "Installing/updating pi via npm..."
    npm install -g "${PI_NPM_PACKAGES[@]}"
    hash -r

    if ! cmd_exist pi; then
        print_color red "pi install completed but pi is not on PATH"
        exit 1
    fi

    pi --help >/dev/null 2>&1
    print_color green "pi ready"
}

installed_packages() {
    local output
    output=$(pi list 2>/dev/null || true)
    awk '/^[[:space:]]+npm:/ {print $1}' <<<"$output"
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
        print_color green "  installing/updating $pkg"
        pi install "$pkg"
    done

    print_color green "Updating pi extensions..."
    pi update
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
