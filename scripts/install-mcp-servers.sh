#!/bin/sh

. $HOME/dotfiles/globals.sh

# Configuration
FILESYSTEM_PATHS="$HOME/www $HOME/src $HOME/dotfiles \
/mnt/c/Users/asolo/winconf"

# Server configs (name:package format)
MCP_SERVERS="
sequential-thinking:@modelcontextprotocol/server-sequential-thinking
filesystem:@modelcontextprotocol/server-filesystem \
$FILESYSTEM_PATHS
fetch:@kazuph/mcp-fetch
browser-tools:@agentdeskai/browser-tools-mcp@1.2.1
playwright:@playwright/mcp
"

# Result tracking
INSTALL_RESULTS=""

# Spinner functions
show_spinner() {
    local server_name="$1"
    local action="$2"
    local command="$3"
    
    printf "[$server_name] - $action "
    
    # Run command in background and show spinner
    eval "$command" &
    local pid=$!
    
    # Show spinning animation with ASCII characters
    local spin_chars="|/-\\"
    local i=0
    while kill -0 $pid 2>/dev/null; do
        case $i in
            0) char="|" ;;
            1) char="/" ;;
            2) char="-" ;;
            3) char="\\" ;;
        esac
        printf "\b%s" "$char"
        sleep 0.2
        i=$(( (i + 1) % 4 ))
    done
    
    wait $pid
    local exit_code=$?
    
    # Clear spinner and show result
    printf "\b"
    
    if [ $exit_code -eq 0 ]; then
        printf "✅\n"
        INSTALL_RESULTS="${INSTALL_RESULTS}${server_name}:SUCCESS:${action}
"
    else
        printf "❌\n"
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
    echo "+----------------------+----------+-------------------+"
    echo "| Server               | Status   | Action            |"
    echo "+----------------------+----------+-------------------+"
    
    printf "%s" "$INSTALL_RESULTS" | while IFS=: read -r server status action; do
        [ -z "$server" ] && continue
        
        case $status in
            SUCCESS) status_display="✅ SUCCESS" ;;
            FAILED)  status_display="❌ FAILED " ;;
            REMOVED) status_display="🗑️ REMOVED" ;;
            SKIPPED) status_display="⚠️  SKIPPED" ;;
            *) status_display="$status" ;;
        esac
        
        printf "| %-20s | %-10s | %-17s |\n" "$server" "$status_display" "$action"
    done
    
    echo "+----------------------+----------+-------------------+"
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

    show_spinner "$server_name" "installing" \
        "claude mcp remove '$server_name' >/dev/null 2>&1; claude mcp add '$server_name' -- npx -y '$*' >/dev/null 2>&1"
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
            printf "[$server] - removing "
            claude mcp remove "$server" >/dev/null 2>&1 && {
                printf "🗑️\n"
                INSTALL_RESULTS="${INSTALL_RESULTS}${server}:REMOVED:removing
"
            } || {
                printf "❌\n"
                INSTALL_RESULTS="${INSTALL_RESULTS}${server}:FAILED:removing
"
            }
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
    show_spinner "brave-search" "installing" \
        "claude mcp remove brave-search >/dev/null 2>&1; claude mcp add brave-search -- env BRAVE_API_KEY='$BRAVE_API_KEY' npx -y @modelcontextprotocol/server-brave-search >/dev/null 2>&1"
} || {
    printf "[brave-search] - skipped (no API key) ⚠️\n"
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

show_spinner "git" "installing package" \
    "npm install -g @cyanheads/git-mcp-server >/dev/null 2>&1"

show_spinner "git" "configuring" \
    "claude mcp remove git >/dev/null 2>&1; claude mcp add git -- npx -y @cyanheads/git-mcp-server >/dev/null 2>&1"

show_summary

echo ""
msg complete
msg restart
