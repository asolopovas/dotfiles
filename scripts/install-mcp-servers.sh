#!/bin/bash

source $HOME/dotfiles/globals.sh

print_color green "Installing MCP Servers for Claude..."

if [ -f .env ]; then
    print_color blue "Loading .env file..."
    export $(grep -v '^#' .env | xargs)
fi

print_color blue "Checking prerequisites..."

if ! command -v node &> /dev/null; then
    print_color red "Node.js is not installed. Please install Node.js first."
    exit 1
fi

if ! command -v npm &> /dev/null; then
    print_color red "npm is not installed. Please install npm first."
    exit 1
fi

if ! command -v claude &> /dev/null; then
    print_color red "Claude CLI is not installed. Please install Claude CLI first."
    exit 1
fi

print_color green "✅ All prerequisites satisfied"

add_mcp_server() {
    local server_name=$1
    local command=$2
    shift 2
    local args=("$@")
    
    print_color blue "Adding MCP server: $server_name"
    
    if claude mcp add "$server_name" -s user -- $command "${args[@]}"; then
        print_color green "✅ $server_name added successfully"
    else
        print_color red "❌ Failed to add $server_name"
        return 1
    fi
}

add_mcp_server "sequential-thinking" "npx" "-y" "@modelcontextprotocol/server-sequential-thinking"
add_mcp_server "filesystem" "npx" "-y" "@modelcontextprotocol/server-filesystem" "$HOME/www" "$HOME/src" "$HOME/dotfiles" "/mnt/c/Users/asolo/winconf"
add_mcp_server "puppeteer" "npx" "-y" "@modelcontextprotocol/server-puppeteer"
add_mcp_server "fetch" "npx" "-y" "@kazuph/mcp-fetch"
add_mcp_server "browser-tools" "npx" "-y" "@agentdeskai/browser-tools-mcp@1.2.1"

if [ -n "$BRAVE_API_KEY" ]; then
    print_color blue "Adding brave-search with BRAVE_API_KEY..."
    if claude mcp add brave-search -s user -- env BRAVE_API_KEY="$BRAVE_API_KEY" npx -y @modelcontextprotocol/server-brave-search; then
        print_color green "✅ brave-search added successfully"
    else
        print_color red "❌ Failed to add brave-search"
    fi
else
    print_color yellow "⚠️  BRAVE_API_KEY not set. Skipping brave-search."
    print_color white "To add brave-search later, set BRAVE_API_KEY in .env file"
fi

print_color blue "Setting up Git MCP server..."

if ! command -v git &> /dev/null; then
    print_color red "Git is not installed. Please install Git first."
    exit 1
fi

if ! command -v gh &> /dev/null; then
    print_color red "GitHub CLI is not installed. Please install GitHub CLI first."
    exit 1
fi

print_color blue "Checking Git authentication and configuration..."

if ! gh auth status &> /dev/null; then
    print_color yellow "⚠️  GitHub CLI not authenticated. Please run 'gh auth login' first."
    print_color blue "This is required for Git operations through MCP."
    exit 1
else
    print_color green "✅ GitHub CLI is authenticated"
fi

GIT_USER_NAME=$(git config --global user.name)
GIT_USER_EMAIL=$(git config --global user.email)

if [ -z "$GIT_USER_NAME" ] || [ -z "$GIT_USER_EMAIL" ]; then
    print_color yellow "⚠️  Git global configuration incomplete:"
    [ -z "$GIT_USER_NAME" ] && print_color red "  - Missing user.name"
    [ -z "$GIT_USER_EMAIL" ] && print_color red "  - Missing user.email"
    print_color blue "Please configure Git with:"
    print_color white "  git config --global user.name \"Your Name\""
    print_color white "  git config --global user.email \"your.email@example.com\""
    exit 1
else
    print_color green "✅ Git configured: $GIT_USER_NAME <$GIT_USER_EMAIL>"
fi

GH_PROTOCOL=$(gh auth status 2>&1 | grep -o 'Git operations protocol: [^,]*' | cut -d' ' -f4)
if [ "$GH_PROTOCOL" = "ssh" ]; then
    print_color blue "Checking SSH key authentication..."
    if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        print_color green "✅ SSH key authentication working"
    else
        print_color yellow "⚠️  SSH key authentication may have issues"
        print_color blue "You may need to add your SSH key to GitHub"
    fi
fi

print_color blue "Configuring Git credential helper..."
GH_CREDENTIAL_HELPER=$(gh auth git-credential)
if [ -n "$GH_CREDENTIAL_HELPER" ]; then
    git config --global credential.helper ""
    git config --global credential.helper "$GH_CREDENTIAL_HELPER"
    print_color green "✅ Git credential helper configured"
else
    print_color yellow "⚠️  GitHub CLI credential helper not available, using existing setup"
fi

print_color blue "Installing @cyanheads/git-mcp-server..."
npm install -g @cyanheads/git-mcp-server

if [ $? -eq 0 ]; then
    print_color green "✅ Git MCP server installed successfully"
else
    print_color red "❌ Failed to install Git MCP server"
    exit 1
fi

add_mcp_server "git" "npx" "-y" "@cyanheads/git-mcp-server"

print_color green "🎉 All MCP servers setup complete!"
print_color blue ""
print_color blue "📋 Installed MCP Servers:"
print_color white "  - sequential-thinking: Structured thinking and problem solving"
print_color white "  - filesystem: File system operations"
print_color white "  - puppeteer: Browser automation"
print_color white "  - fetch: Web content fetching"
print_color white "  - browser-tools: Browser development tools"
if [ -n "$BRAVE_API_KEY" ]; then
    print_color white "  - brave-search: Web search via Brave API"
fi
print_color white "  - git: Git repository operations"
print_color blue ""
print_color blue "🔐 Git Authentication Summary:"
print_color white "  - GitHub CLI: $(gh auth status 2>&1 | grep -o 'account [^(]*' | cut -d' ' -f2)"
print_color white "  - Protocol: $GH_PROTOCOL"
print_color white "  - Git User: $GIT_USER_NAME <$GIT_USER_EMAIL>"
print_color white "  - Credential Helper: GitHub CLI"
print_color blue ""
print_color yellow "📝 Restart Claude to activate all MCP servers"
print_color blue "💡 Use 'claude mcp list' to verify all servers are active"