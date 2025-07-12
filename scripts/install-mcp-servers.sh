#!/bin/sh

. $HOME/dotfiles/globals.sh

# Configuration
FILESYSTEM_PERMISSIONS_FILE="$HOME/.mcp_folder_permissions"
[ ! -f "$FILESYSTEM_PERMISSIONS_FILE" ] && touch "$FILESYSTEM_PERMISSIONS_FILE"

# Time tracking
START_TIME=$(date +%s)

# Check filesystem permissions
if [ -s "$FILESYSTEM_PERMISSIONS_FILE" ]; then
    FILESYSTEM_PATHS=$(tr '\n' ' ' < "$FILESYSTEM_PERMISSIONS_FILE")
    FILESYSTEM_ENABLED=true
else
    FILESYSTEM_ENABLED=false
    FILESYSTEM_PATHS=""
fi

# Server configs (name:package format)
MCP_SERVERS="sequential-thinking:@modelcontextprotocol/server-sequential-thinking
fetch:@kazuph/mcp-fetch
browser-tools:@agentdeskai/browser-tools-mcp@1.2.1
playwright:@playwright/mcp"

# Add filesystem server if enabled
[ "$FILESYSTEM_ENABLED" = true ] && MCP_SERVERS="$MCP_SERVERS
filesystem:@modelcontextprotocol/server-filesystem $FILESYSTEM_PATHS"

# Result tracking
INSTALL_RESULTS=""
TABLE_FILE="/tmp/mcp_table_$$"

# Initialize table display
init_table() {
    echo "+----------------------+--------------+" > "$TABLE_FILE"
    echo "| Server               | Status       |" >> "$TABLE_FILE"
    echo "+----------------------+--------------+" >> "$TABLE_FILE"

    # Add rows for each server with initial pending status
    echo "$MCP_SERVERS" | while IFS=: read -r name package; do
        [ -z "$name" ] && continue
        printf "| %-20s | %-13s |\n" "$name" "⏳ Wait" >> "$TABLE_FILE"
    done

    # Add additional servers
    [ -n "$BRAVE_API_KEY" ] && printf "| %-20s | %-12s |\n" "brave-search" "⏳ Wait" >> "$TABLE_FILE"
    printf "| %-20s | %-13s |\n" "git" "⏳ Wait" >> "$TABLE_FILE"

    echo "+----------------------+--------------+" >> "$TABLE_FILE"
}

# Update table row with spinner or final status
update_table_row() {
    local server_name="$1"
    local status="$2"
    local temp_file="/tmp/mcp_table_temp_$$"

    # Replace the line for this server
    while IFS= read -r line; do
        if echo "$line" | grep -q "| $server_name "; then
            printf "| %-20s | %-13s |\n" "$server_name" "$status"
        else
            echo "$line"
        fi
    done < "$TABLE_FILE" > "$temp_file"

    mv "$temp_file" "$TABLE_FILE"
}

# Display current table
show_table() {
    printf "\r\033[K"  # Clear current line
    printf "\033[s"    # Save cursor position
    printf "\033[H"    # Move to top
    gum style --foreground 32 "Installing MCP Servers..."
    echo ""
    cat "$TABLE_FILE"
    echo ""
    printf "\033[u"    # Restore cursor position
}

# Execute with table updates
run_with_table() {
    local server_name="$1"
    local action="$2"
    local command="$3"

    # Show spinner in table
    update_table_row "$server_name" "🔄 Setup"
    show_table

    if sh -c "$command" >/dev/null 2>&1; then
        update_table_row "$server_name" "✅ OK"
        INSTALL_RESULTS="${INSTALL_RESULTS}${server_name}:SUCCESS:${action}
"
        return 0
    else
        update_table_row "$server_name" "❌ Failed"
        INSTALL_RESULTS="${INSTALL_RESULTS}${server_name}:FAILED:${action}
"
        return 1
    fi
}

# Show summary with stats
show_summary() {
    [ -z "$INSTALL_RESULTS" ] && return 0

    # Calculate elapsed time
    END_TIME=$(date +%s)
    ELAPSED=$((END_TIME - START_TIME))
    ELAPSED_FORMATTED=$(printf "%02d:%02d" $((ELAPSED / 60)) $((ELAPSED % 60)))

    # Count results by iterating through INSTALL_RESULTS
    SUCCESS_COUNT=0
    FAILED_COUNT=0
    SKIPPED_COUNT=0
    REMOVED_COUNT=0

    # Save to temp file to avoid subshell variable issues
    echo "$INSTALL_RESULTS" | while IFS=: read -r server status action; do
        [ -z "$server" ] && continue
        case $status in
            SUCCESS) echo "SUCCESS" ;;
            FAILED) echo "FAILED" ;;
            REMOVED) echo "REMOVED" ;;
            SKIPPED) echo "SKIPPED" ;;
        esac
    done > /tmp/mcp_status_count

    # Count each status type
    if [ -f /tmp/mcp_status_count ]; then
        SUCCESS_COUNT=$(grep -c "SUCCESS" /tmp/mcp_status_count 2>/dev/null | head -1 || echo "0")
        FAILED_COUNT=$(grep -c "FAILED" /tmp/mcp_status_count 2>/dev/null | head -1 || echo "0")
        REMOVED_COUNT=$(grep -c "REMOVED" /tmp/mcp_status_count 2>/dev/null | head -1 || echo "0")
        SKIPPED_COUNT=$(grep -c "SKIPPED" /tmp/mcp_status_count 2>/dev/null | head -1 || echo "0")
        rm -f /tmp/mcp_status_count
    fi

    echo ""
    gum style --foreground 32 "🎉 Installation Complete!"
    gum style --foreground 244 "⏱️ $ELAPSED_FORMATTED | ✅ $SUCCESS_COUNT | ❌ $FAILED_COUNT | ⚠️ $SKIPPED_COUNT | 🗑️ $REMOVED_COUNT"

    # Show filesystem paths if enabled
    if [ "$FILESYSTEM_ENABLED" = true ]; then
        PATHS_COUNT=$(wc -l < "$FILESYSTEM_PERMISSIONS_FILE" 2>/dev/null || echo "0")
        gum style --foreground 244 "📂 Filesystem: $PATHS_COUNT paths configured"
    fi
}

# Check if server is configured correctly
check_server_config() {
    local server_name="$1"
    shift 1
    local expected_command="npx -y $*"
    local current_config=$(claude mcp list 2>/dev/null | grep "^$server_name:" | cut -d: -f2- | sed 's/^ *//')
    [ "$current_config" = "$expected_command" ]
}

# Messages
msg() {
    case $1 in
    title) gum style --foreground 32 "Installing MCP Servers..." ;;
    complete) gum style --foreground 32 "🎉 Setup complete!" ;;
    restart) gum style --foreground 33 "⚠️ Restart Claude to activate servers" ;;
    fail) gum style --foreground 31 "❌ $2" ;;
    warn) gum style --foreground 33 "⚠️  $2" ;;
    esac
}

add_mcp_server() {
    local server_name=$1
    shift 1

    if check_server_config "$server_name" "$@"; then
        update_table_row "$server_name" "✅ OK"
        show_table
        INSTALL_RESULTS="${INSTALL_RESULTS}${server_name}:SUCCESS:already configured
"
        return 0
    fi

    run_with_table "$server_name" "setup" \
        "claude mcp remove '$server_name' 2>/dev/null; claude mcp add '$server_name' -- npx -y $*"
    show_table
}

remove_unlisted_servers() {
    current_servers_output=$(claude mcp list 2>/dev/null) || return 0

    # Skip if no servers or no colons
    [ -z "$current_servers_output" ] || ! echo "$current_servers_output" | grep -q ":" && return 0

    # Extract server names
    current_servers=$(echo "$current_servers_output" | awk -F: '{if (NF > 1) print $1}' | sed 's/^[ \t]*//;s/[ \t]*$//')

    for server in $current_servers; do
        [ -z "$server" ] && continue

        should_keep=false

        # Always keep brave-search and git
        case "$server" in
            "brave-search"|"git") should_keep=true ;;
            "filesystem") [ "$FILESYSTEM_ENABLED" = true ] && should_keep=true ;;
            *)
                # Check if in MCP_SERVERS list
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
            claude mcp remove "$server" >/dev/null 2>&1
            INSTALL_RESULTS="${INSTALL_RESULTS}${server}:REMOVED:removed
"
        fi
    done
}

msg title


remove_unlisted_servers

# Initialize table
init_table
clear
gum style --foreground 32 "Installing MCP Servers..."
echo ""
cat "$TABLE_FILE"
echo ""

[ -f "$HOME/.env" ] && export $(grep -v '^#' "$HOME/.env" | xargs)

# Check dependencies
missing_deps=""
for cmd in node npm claude git; do
    command -v "$cmd" >/dev/null 2>&1 || missing_deps="$missing_deps $cmd"
done

if [ -n "$missing_deps" ]; then
    msg fail "Missing dependencies:$missing_deps"
    exit 1
fi

gh_available=false
command -v gh >/dev/null 2>&1 && gh_available=true
[ "$gh_available" = false ] && msg warn "GitHub CLI (gh) not found - git features limited"

# Install MCP servers
while IFS=: read -r name package; do
    [ -z "$name" ] && continue
    add_mcp_server "$name" $package
done << EOF
$MCP_SERVERS
EOF

# Brave search
if [ -n "$BRAVE_API_KEY" ]; then
    expected_brave_cmd="env BRAVE_API_KEY=$BRAVE_API_KEY npx -y @modelcontextprotocol/server-brave-search"
    current_brave_config=$(claude mcp list 2>/dev/null | grep "^brave-search:" | cut -d: -f2- | sed 's/^ *//')

    if [ "$current_brave_config" = "$expected_brave_cmd" ]; then
        update_table_row "brave-search" "✅ OK"
        show_table
        INSTALL_RESULTS="${INSTALL_RESULTS}brave-search:SUCCESS:already configured
"
    else
        run_with_table "brave-search" "setup" \
            "claude mcp remove brave-search 2>/dev/null; claude mcp add brave-search -- env BRAVE_API_KEY='$BRAVE_API_KEY' npx -y @modelcontextprotocol/server-brave-search"
        show_table
    fi
else
    update_table_row "brave-search" "⚠️ Skip"
    show_table
    INSTALL_RESULTS="${INSTALL_RESULTS}brave-search:SKIPPED:no API key
"
fi

# Git setup
if [ "$gh_available" = true ]; then
    gh auth status >/dev/null 2>&1 || { msg fail "gh auth login required"; exit 1; }
else
    msg warn "Skipping GitHub auth check (gh not available)"
fi

[ -n "$(git config --global user.name)" ] && [ -n "$(git config --global user.email)" ] || {
    msg fail "git config --global user.name/email required"
    exit 1
}

# Git server
if check_server_config "git" "@cyanheads/git-mcp-server"; then
    update_table_row "git" "✅ OK"
    show_table
    INSTALL_RESULTS="${INSTALL_RESULTS}git:SUCCESS:already configured
"
else
    run_with_table "git" "setup" \
        "npm install -g @cyanheads/git-mcp-server; claude mcp remove git 2>/dev/null; claude mcp add git -- npx -y @cyanheads/git-mcp-server"
    show_table
fi

# Final table display
show_table

show_summary

echo ""
msg complete
msg restart

# Cleanup
rm -f "$TABLE_FILE"
