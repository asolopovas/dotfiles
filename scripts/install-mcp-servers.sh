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
puppeteer:@modelcontextprotocol/server-puppeteer
fetch:@kazuph/mcp-fetch
browser-tools:@agentdeskai/browser-tools-mcp@1.2.1
playwright:@playwright/mcp
"

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

    printf "  %-20s " "$server_name"
    claude mcp add "$server_name" -s user -- npx -y "$@" >/dev/null 2>&1 && {
        printf "\033[0;32m✅\033[0m\n"
    } || {
        printf "\033[0;31m❌\033[0m\n"
        return 1
    }
}

msg title
echo ""
printf "  %-20s %s\n" "Server" "Status"
printf "  %-20s %s\n" "------" "------"

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
    printf "  %-20s " "brave-search"
    claude mcp add brave-search -s user -- \
        env BRAVE_API_KEY="$BRAVE_API_KEY" \
        npx -y @modelcontextprotocol/server-brave-search >/dev/null 2>&1 && {
        printf "\033[0;32m✅\033[0m\n"
    } || {
        printf "\033[0;31m❌\033[0m\n"
    }
} || printf "  %-20s \033[0;33m⚠️  Skipped (no API key)\033[0m\n" "brave-search"

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

npm install -g @cyanheads/git-mcp-server >/dev/null 2>&1
add_mcp_server "git" "@cyanheads/git-mcp-server"

msg complete
msg restart
