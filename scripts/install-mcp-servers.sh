#!/bin/sh

. $HOME/dotfiles/globals.sh

FILESYSTEM_PERMISSIONS_FILE="$HOME/.mcp_folder_permissions"
[ ! -f "$FILESYSTEM_PERMISSIONS_FILE" ] && touch "$FILESYSTEM_PERMISSIONS_FILE"

START_TIME=$(date +%s)

if [ -s "$FILESYSTEM_PERMISSIONS_FILE" ]; then
    FILESYSTEM_PATHS=$(tr '\n' ' ' < "$FILESYSTEM_PERMISSIONS_FILE")
    FILESYSTEM_ENABLED=true
else
    FILESYSTEM_ENABLED=false
    FILESYSTEM_PATHS=""
fi

MCP_SERVERS="sequential-thinking:@modelcontextprotocol/server-sequential-thinking
fetch:@kazuph/mcp-fetch
browser-tools:@agentdeskai/browser-tools-mcp@1.2.1
playwright:@playwright/mcp"

[ "$FILESYSTEM_ENABLED" = true ] && MCP_SERVERS="$MCP_SERVERS
filesystem:@modelcontextprotocol/server-filesystem $FILESYSTEM_PATHS"

INSTALL_RESULTS=""

run_with_spinner() {
    local server_name="$1"
    local action="$2"
    local command="$3"

    if gum spin --spinner dot --title "Installing $server_name..." -- sh -c "$command"; then
        INSTALL_RESULTS="${INSTALL_RESULTS}${server_name}:SUCCESS:${action}
"
        return 0
    else
        INSTALL_RESULTS="${INSTALL_RESULTS}${server_name}:FAILED:${action}
"
        return 1
    fi
}

show_summary() {
    [ -z "$INSTALL_RESULTS" ] && return 0

    END_TIME=$(date +%s)
    ELAPSED=$((END_TIME - START_TIME))
    ELAPSED_FORMATTED=$(printf "%02d:%02d" $((ELAPSED / 60)) $((ELAPSED % 60)))

    SUCCESS_COUNT=$(echo "$INSTALL_RESULTS" | grep -c "SUCCESS")
    FAILED_COUNT=$(echo "$INSTALL_RESULTS" | grep -c "FAILED") 
    SKIPPED_COUNT=$(echo "$INSTALL_RESULTS" | grep -c "SKIPPED")
    REMOVED_COUNT=$(echo "$INSTALL_RESULTS" | grep -c "REMOVED")

    echo ""
    echo "┌─────────────────────────────────────────────────────────────────┐"
    echo "│                        🎉 Installation Results                  │"
    echo "├─────────────────────────────────────────────────────────────────┤"
    echo "│ Server               │ Status      │ Action                     │"
    echo "├─────────────────────────────────────────────────────────────────┤"
    
    echo "$INSTALL_RESULTS" | while IFS=: read -r server status action; do
        [ -z "$server" ] && continue
        
        case "$status" in
            "SUCCESS") status_icon="✅" ;;
            "FAILED") status_icon="❌" ;;
            "SKIPPED") status_icon="⚠️ " ;;
            "REMOVED") status_icon="🗑️ " ;;
            *) status_icon="  " ;;
        esac
        
        printf "│ %-20s │ %s %-8s │ %-26s │\n" \
            "${server}" "${status_icon}" "${status}" "${action}"
    done
    
    echo "├─────────────────────────────────────────────────────────────────┤"
    printf "│ %-63s │\n" "⏱️  ${ELAPSED_FORMATTED} | ✅ ${SUCCESS_COUNT} | ❌ ${FAILED_COUNT} | ⚠️ ${SKIPPED_COUNT} | 🗑️ ${REMOVED_COUNT}"
    echo "└─────────────────────────────────────────────────────────────────┘"

    if [ "$FILESYSTEM_ENABLED" = true ]; then
        PATHS_COUNT=$(wc -l < "$FILESYSTEM_PERMISSIONS_FILE" 2>/dev/null || echo "0")
        echo "📂 Filesystem: $PATHS_COUNT paths configured"
    fi
}

check_server_config() {
    local server_name="$1"
    shift 1
    local expected_command="npx -y $*"
    local current_config=$(claude mcp list 2>/dev/null | grep "^$server_name:" | cut -d: -f2- | sed 's/^ *//')
    [ "$current_config" = "$expected_command" ]
}

add_mcp_server() {
    local server_name=$1
    shift 1

    if check_server_config "$server_name" "$@"; then
        INSTALL_RESULTS="${INSTALL_RESULTS}${server_name}:SUCCESS:already configured
"
        return 0
    fi

    run_with_spinner "$server_name" "setup" \
        "claude mcp remove '$server_name' 2>/dev/null; claude mcp add '$server_name' -- npx -y $*"
}

remove_unlisted_servers() {
    current_servers_output=$(claude mcp list 2>/dev/null) || return 0
    [ -z "$current_servers_output" ] || ! echo "$current_servers_output" | grep -q ":" && return 0

    current_servers=$(echo "$current_servers_output" | awk -F: '{if (NF > 1) print $1}' | sed 's/^[ \t]*//;s/[ \t]*$//')

    for server in $current_servers; do
        [ -z "$server" ] && continue
        should_keep=false

        case "$server" in
            "brave-search"|"git") should_keep=true ;;
            "filesystem") [ "$FILESYSTEM_ENABLED" = true ] && should_keep=true ;;
            *)
                while IFS=: read -r name package; do
                    [ -z "$name" ] && continue
                    name=$(echo "$name" | tr -d ' ')
                    if [ "$server" = "$name" ]; then
                        should_keep=true
                        break
                    fi
                done << EOF
$MCP_SERVERS
EOF
                ;;
        esac

        if [ "$should_keep" = false ]; then
            gum spin --spinner dot --title "Removing $server..." -- claude mcp remove "$server" 2>/dev/null
            INSTALL_RESULTS="${INSTALL_RESULTS}${server}:REMOVED:removed
"
        fi
    done
}

echo "🚀 Installing MCP Servers..."

remove_unlisted_servers

[ -f "$HOME/.env" ] && export $(grep -v '^#' "$HOME/.env" | xargs)

missing_deps=""
for cmd in node npm claude git; do
    command -v "$cmd" >/dev/null 2>&1 || missing_deps="$missing_deps $cmd"
done

if [ -n "$missing_deps" ]; then
    gum style --foreground 31 "❌ Missing dependencies:$missing_deps"
    exit 1
fi

gh_available=false
command -v gh >/dev/null 2>&1 && gh_available=true
[ "$gh_available" = false ] && gum style --foreground 33 "⚠️ GitHub CLI (gh) not found - git features limited"

while IFS=: read -r name package; do
    [ -z "$name" ] && continue
    add_mcp_server "$name" $package
done << EOF
$MCP_SERVERS
EOF

if [ -n "$BRAVE_API_KEY" ]; then
    expected_brave_cmd="env BRAVE_API_KEY=$BRAVE_API_KEY npx -y @modelcontextprotocol/server-brave-search"
    current_brave_config=$(claude mcp list 2>/dev/null | grep "^brave-search:" | cut -d: -f2- | sed 's/^ *//')

    if [ "$current_brave_config" = "$expected_brave_cmd" ]; then
        INSTALL_RESULTS="${INSTALL_RESULTS}brave-search:SUCCESS:already configured
"
    else
        run_with_spinner "brave-search" "setup" \
            "claude mcp remove brave-search 2>/dev/null; claude mcp add brave-search -- env BRAVE_API_KEY='$BRAVE_API_KEY' npx -y @modelcontextprotocol/server-brave-search"
    fi
else
    gum style --foreground 33 "⚠️ brave-search skipped (no API key)"
    INSTALL_RESULTS="${INSTALL_RESULTS}brave-search:SKIPPED:no API key
"
fi

if [ "$gh_available" = true ]; then
    gh auth status >/dev/null 2>&1 || { 
        gum style --foreground 31 "❌ gh auth login required"
        exit 1
    }
else
    gum style --foreground 33 "⚠️ Skipping GitHub auth check (gh not available)"
fi

[ -n "$(git config --global user.name)" ] && [ -n "$(git config --global user.email)" ] || {
    gum style --foreground 31 "❌ git config --global user.name/email required"
    exit 1
}

if check_server_config "git" "@cyanheads/git-mcp-server"; then
    INSTALL_RESULTS="${INSTALL_RESULTS}git:SUCCESS:already configured
"
else
    run_with_spinner "git" "setup" \
        "npm install -g @cyanheads/git-mcp-server; claude mcp remove git 2>/dev/null; claude mcp add git -- npx -y @cyanheads/git-mcp-server"
fi

show_summary

echo ""
gum style --foreground 32 "🎉 Setup complete!"
gum style --foreground 33 "⚠️ Restart Claude to activate servers"