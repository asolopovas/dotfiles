#!/bin/bash
. "$HOME/dotfiles/globals.sh"
[ -f "$HOME/.env" ] && . "$HOME/.env"

command -v gum >/dev/null || "$HOME/dotfiles/scripts/install-gum.sh"

# MCP servers configuration
declare -A mcp_servers=(
    [duckduckgo]=${DUCKDUCKGO:-true}
    [context7]=${CONTEXT7:-true}
    [fetch]=${FETCH:-true}
    [filesystem]=${FILESYSTEM:-false}
    [git]=${GIT:-true}
    [github]=${GITHUB:-true}
    [playwright]=${PLAYWRIGHT:-true}
    [sequential-thinking]=${SEQUENTIAL_THINKING:-true}
)

# Server package mappings
get_server_package() {
    case "$1" in
    filesystem) echo "@modelcontextprotocol/server-filesystem /home/andrius" ;;
    fetch) echo "@kazuph/mcp-fetch" ;;
    git) echo "@cyanheads/git-mcp-server" ;;
    playwright) echo "@playwright/mcp" ;;
    duckduckgo) echo "@oevortex/ddg_search" ;;
    github) echo "@modelcontextprotocol/server-github" ;;
    sequential-thinking) echo "@modelcontextprotocol/server-sequential-thinking" ;;
    context7) echo "@upstash/context7-mcp" ;;
    *) echo "@modelcontextprotocol/server-$1" ;;
    esac
}

# Check if server is already configured
is_server_configured() {
    echo "$claude_servers" | grep -q "^$1$"
}

# Add server with optional environment
add_server() {
    server="$1"
    env_vars="$2"
    package=$(get_server_package "$server")

    if [ -n "$env_vars" ]; then
        claude mcp add "$server" -- $env_vars npx $package && echo "Added $server"
    else
        claude mcp add "$server" -- npx $package && echo "Added $server"
    fi
}

# Get current Claude servers
claude_servers=$(claude mcp list 2>/dev/null | grep -v "No MCP servers configured" | cut -d: -f1)

# Build enabled servers list
enabled_servers=""
for server in "${!mcp_servers[@]}"; do
    if [ "${mcp_servers[$server]}" = "true" ]; then
        enabled_servers="$enabled_servers $server"
    fi
done

# Remove servers not in enabled list
for server in $claude_servers; do
    echo "$enabled_servers" | grep -q "\b$server\b" || { claude mcp remove "$server" && echo "Removed $server"; }
done

# Refresh server list
claude_servers=$(claude mcp list 2>/dev/null | grep -v "No MCP servers configured" | cut -d: -f1)

# Add enabled servers
if [ "${mcp_servers[duckduckgo]}" = "true" ]; then
    is_server_configured "duckduckgo" || add_server "duckduckgo"
fi

if [ "${mcp_servers[fetch]}" = "true" ]; then
    is_server_configured "fetch" || add_server "fetch"
fi

if [ "${mcp_servers[filesystem]}" = "true" ]; then
    is_server_configured "filesystem" || add_server "filesystem"
fi

if [ "${mcp_servers[git]}" = "true" ]; then
    is_server_configured "git" || add_server "git"
fi

if [ "${mcp_servers[github]}" = "true" ]; then
    is_server_configured "github" || {
        command -v gh >/dev/null && gh auth status >/dev/null 2>&1 && add_server "github"
    }
fi

if [ "${mcp_servers[playwright]}" = "true" ]; then
    is_server_configured "playwright" || add_server "playwright"
fi

if [ "${mcp_servers[sequential-thinking]}" = "true" ]; then
    is_server_configured "sequential-thinking" || add_server "sequential-thinking"
fi

if [ "${mcp_servers[context7]}" = "true" ]; then
    is_server_configured "context7" || add_server "context7"
fi

gum style --foreground 32 "✅ MCP sync complete"
