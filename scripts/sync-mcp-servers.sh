#!/bin/bash
. "$HOME/dotfiles/globals.sh"
[ -f "$HOME/.env" ] && . "$HOME/.env"

command -v gum >/dev/null || "$HOME/dotfiles/scripts/install-gum.sh"

declare -A mcp_servers=(
    [context7]=${CONTEXT7:-true}
    [git]=${GIT:-true}
    [github]=${GITHUB:-true}
    [playwright]=${PLAYWRIGHT:-true}
    [sequential-thinking]=${SEQUENTIAL_THINKING:-true}
)

get_server_package() {
    case "$1" in
    context7) echo "@upstash/context7-mcp" ;;
    git) echo "@cyanheads/git-mcp-server" ;;
    github) echo "@modelcontextprotocol/server-github" ;;
    playwright) echo "@playwright/mcp" ;;
    sequential-thinking) echo "@modelcontextprotocol/server-sequential-thinking" ;;
    *) echo "@modelcontextprotocol/server-$1" ;;
    esac
}

get_claude_servers() {
    claude mcp list 2>/dev/null | grep -v "No MCP servers configured" | grep -v "Checking MCP server health" | cut -d: -f1
}

is_server_configured() {
    get_claude_servers | grep -q "^$1$"
}

add_server() {
    local server="$1"
    local env_vars="$2"
    local package=$(get_server_package "$server")
    
    local cmd="claude mcp add \"$server\" --"
    [ -n "$env_vars" ] && cmd="$cmd $env_vars"
    cmd="$cmd npx $package"
    
    eval $cmd && echo "Added $server"
}

remove_unconfigured_servers() {
    local enabled_servers=$(printf "%s\n" "${!mcp_servers[@]}" | grep -E "$(IFS=\|; echo "${!mcp_servers[*]}")")
    
    for server in $(get_claude_servers); do
        if [ "${mcp_servers[$server]}" != "true" ]; then
            claude mcp remove "$server" && echo "Removed $server"
        fi
    done
}

add_configured_servers() {
    for server in "${!mcp_servers[@]}"; do
        [ "${mcp_servers[$server]}" != "true" ] && continue
        
        if ! is_server_configured "$server"; then
            if [ "$server" = "github" ]; then
                command -v gh >/dev/null && gh auth status >/dev/null 2>&1 && add_server "$server"
            else
                add_server "$server"
            fi
        fi
    done
}

remove_unconfigured_servers
add_configured_servers

gum style --foreground 32 "✅ MCP sync complete"