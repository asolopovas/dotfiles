#!/bin/sh

. $HOME/dotfiles/globals.sh

# Configuration
FILESYSTEM_PERMISSIONS_FILE="$HOME/.mcp_folder_permissions"

# Check if filesystem permissions file exists and has content
if [ -f "$FILESYSTEM_PERMISSIONS_FILE" ] && [ -s "$FILESYSTEM_PERMISSIONS_FILE" ]; then
    FILESYSTEM_PATHS=$(cat "$FILESYSTEM_PERMISSIONS_FILE" | tr '\n' ' ')
    FILESYSTEM_ENABLED=true
else
    FILESYSTEM_ENABLED=false
    FILESYSTEM_PATHS=""
fi

# Server configs (name:package format) - filesystem only included if enabled
MCP_SERVERS="
sequential-thinking:@modelcontextprotocol/server-sequential-thinking
fetch:@kazuph/mcp-fetch
browser-tools:@agentdeskai/browser-tools-mcp@1.2.1
playwright:@playwright/mcp
"

# Add filesystem server only if permissions file exists and has content
if [ "$FILESYSTEM_ENABLED" = true ]; then
    MCP_SERVERS="$MCP_SERVERS
filesystem:@modelcontextprotocol/server-filesystem $FILESYSTEM_PATHS"
fi

# Result tracking
INSTALL_RESULTS=""

# Spinner functions
show_spinner() {
    local server_name="$1"
    local action="$2"
    local command="$3"
    
    printf "\r\033[K" # Clear line
    printf " [%s] %s" "$server_name" "$action"
    
    # Run command in background and show spinner
    eval "$command" &
    local pid=$!
    
    # Show spinning animation with ASCII characters at the beginning
    local spin_chars="|/-\\"
    local i=0
    while kill -0 $pid 2>/dev/null; do
        case $i in
            0) char="|" ;;
            1) char="/" ;;
            2) char="-" ;;
            3) char="\\" ;;
        esac
        printf "\r%s [%s] %s" "$char" "$server_name" "$action"
        sleep 0.2
        i=$(( (i + 1) % 4 ))
    done
    
    wait $pid
    local exit_code=$?
    
    # Clear line and show result
    printf "\r\033[K"
    
    if [ $exit_code -eq 0 ]; then
        printf "✅ [%s] %s\n" "$server_name" "$action"
        INSTALL_RESULTS="${INSTALL_RESULTS}${server_name}:SUCCESS:${action}
"
    else
        printf "❌ [%s] %s\n" "$server_name" "$action"
        INSTALL_RESULTS="${INSTALL_RESULTS}${server_name}:FAILED:${action}
"
    fi
    
    return $exit_code
}

# Summary function
show_summary() {
    echo ""
    print_color cyan "📊 Installation Summary:"
    echo ""
    
    # MySQL-style table
    echo "+----------------------+-------------+-------------------+"
    echo "| Server               | Status      | Action            |"
    echo "+----------------------+-------------+-------------------+"
    
    printf "%s" "$INSTALL_RESULTS" | while IFS=: read -r server status action; do
        [ -z "$server" ] && continue
        
        case $status in
            SUCCESS) status_display="✅ SUCCESS " ;;
            FAILED)  status_display="❌ FAILED  " ;;
            REMOVED) status_display="🗑️ REMOVED " ;;
            SKIPPED) status_display="⚠️  SKIPPED" ;;
            *) status_display="$status" ;;
        esac
        
        printf "| %-20s | %-11s | %-17s |\n" "$server" "$status_display" "$action"
    done
    
    echo "+----------------------+-------------+-------------------+"
}

# Check if server is already correctly configured
check_server_config() {
    local server_name="$1"
    shift 1
    local expected_command="npx -y $*"
    
    # Get current server configuration
    local current_config=$(claude mcp list 2>/dev/null | grep "^$server_name:" | cut -d: -f2- | sed 's/^ *//')
    
    if [ "$current_config" = "$expected_command" ]; then
        return 0  # Already correctly configured
    else
        return 1  # Needs update
    fi
}

# Messages
msg() {
    case $1 in
    title) print_color green "Installing MCP Servers..." ;;
    add) print_color blue "Adding: $2" ;;
    ok) print_color green "✅ $2" ;;
    fail) print_color red "❌ $2" ;;
    warn) print_color yellow "⚠️  $2" ;;
    complete) print_color green "🎉 Setup complete!" ;;
    restart) print_color yellow \
        "⚠️  Restart Claude to activate servers" ;;
    esac
}

add_mcp_server() {
    server_name=$1
    shift 1

    # Check if server is already correctly configured
    if check_server_config "$server_name" "$@"; then
        printf "✅ [%s] already configured\n" "$server_name"
        INSTALL_RESULTS="${INSTALL_RESULTS}${server_name}:SKIPPED:already configured
"
        return 0
    fi

    show_spinner "$server_name" "setup" \
        "claude mcp remove '$server_name' >/dev/null 2>&1; claude mcp add '$server_name' -- npx -y $* >/dev/null 2>&1"
}

remove_unlisted_servers() {
    # Get list of current MCP servers
    current_servers=$(claude mcp list 2>/dev/null | awk -F: '{print $1}' || true)
    
    # Remove servers not in our list
    for server in $current_servers; do
        should_keep=false
        
        # Check if it's brave-search or git (always keep)
        if [ "$server" = "brave-search" ] || [ "$server" = "git" ]; then
            should_keep=true
        # Special handling for filesystem - remove if permissions file is empty
        elif [ "$server" = "filesystem" ] && [ "$FILESYSTEM_ENABLED" = false ]; then
            should_keep=false
        else
            # Check if server is in MCP_SERVERS list
            while IFS=: read -r name package; do
                [ -z "$name" ] && continue
                name=$(echo "$name" | tr -d ' ')  # Remove any whitespace
                if [ "$server" = "$name" ]; then
                    should_keep=true
                    break
                fi
            done << EOF
$MCP_SERVERS
EOF
        fi
        
        if [ "$should_keep" = false ]; then
            printf "🗑️  [%s] removed\n" "$server"
            claude mcp remove "$server" >/dev/null 2>&1
            INSTALL_RESULTS="${INSTALL_RESULTS}${server}:REMOVED:removed
"
        fi
    done
}

msg title
echo ""

# Remove unlisted servers first
remove_unlisted_servers

echo ""
print_color cyan "📦 Installing MCP Servers:"
echo ""

[ -f .env ] && export $(grep -v '^#' .env | xargs)

# Check required dependencies
for cmd in node npm claude git; do
    command -v $cmd >/dev/null 2>&1 || {
        msg fail "$cmd"
        exit 1
    }
done

# Check optional dependencies
gh_available=false
command -v gh >/dev/null 2>&1 && gh_available=true

if [ "$gh_available" = false ]; then
    msg warn "GitHub CLI (gh) not found - git MCP server features may be limited"
fi

# Install MCP servers
printf "%s\n" "$MCP_SERVERS" |
    while IFS=: read -r name package; do
        [ -z "$name" ] && continue
        add_mcp_server "$name" $package
    done

# Brave search
[ -n "$BRAVE_API_KEY" ] && {
    # Check if brave-search is already correctly configured
    expected_brave_cmd="env BRAVE_API_KEY=$BRAVE_API_KEY npx -y @modelcontextprotocol/server-brave-search"
    current_brave_config=$(claude mcp list 2>/dev/null | grep "^brave-search:" | cut -d: -f2- | sed 's/^ *//')
    
    if [ "$current_brave_config" = "$expected_brave_cmd" ]; then
        printf "✅ [brave-search] already configured\n"
        INSTALL_RESULTS="${INSTALL_RESULTS}brave-search:SKIPPED:already configured
"
    else
        show_spinner "brave-search" "setup" \
            "claude mcp remove brave-search >/dev/null 2>&1; claude mcp add brave-search -- env BRAVE_API_KEY='$BRAVE_API_KEY' npx -y @modelcontextprotocol/server-brave-search >/dev/null 2>&1"
    fi
} || {
    printf "⚠️  [brave-search] skipped (no API key)\n"
    INSTALL_RESULTS="${INSTALL_RESULTS}brave-search:SKIPPED:no API key
"
}

# Git setup
if [ "$gh_available" = true ]; then
    gh auth status >/dev/null 2>&1 || {
        msg fail "gh auth login required"
        exit 1
    }
else
    msg warn "Skipping GitHub auth check (gh not available)"
fi

[ -n "$(git config --global user.name)" ] &&
    [ -n "$(git config --global user.email)" ] || {
    msg fail "git config --global user.name/email required"
    exit 1
}

# Check if git server is already correctly configured
if check_server_config "git" "@cyanheads/git-mcp-server"; then
    printf "✅ [git] already configured\n"
    INSTALL_RESULTS="${INSTALL_RESULTS}git:SKIPPED:already configured
"
else
    show_spinner "git" "setup" \
        "npm install -g @cyanheads/git-mcp-server >/dev/null 2>&1; claude mcp remove git >/dev/null 2>&1; claude mcp add git -- npx -y @cyanheads/git-mcp-server >/dev/null 2>&1"
fi

show_summary

echo ""
msg complete
msg restart
