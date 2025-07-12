#!/bin/sh
. "$HOME/dotfiles/globals.sh"
[ -f "$HOME/.env" ] && . "$HOME/.env"

install_gum() {
    command -v gum >/dev/null && return 0
    echo "Installing gum..."
    if command -v brew >/dev/null; then
        brew install gum
    elif command -v apt-get >/dev/null; then
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
        echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
        sudo apt update && sudo apt install gum
    elif command -v yum >/dev/null; then
        echo '[charm]
name=Charm
baseurl=https://repo.charm.sh/yum/
enabled=1
gpgcheck=1
gpgkey=https://repo.charm.sh/yum/gpg.key' | sudo tee /etc/yum.repos.d/charm.repo
        sudo yum install gum
    else
        echo "❌ Cannot install gum automatically. Please install it manually."
        exit 1
    fi
}

install_gum

FILESYSTEM_PERMISSIONS_FILE="$HOME/.mcp_folder_permissions"
[ -f "$FILESYSTEM_PERMISSIONS_FILE" ] || touch "$FILESYSTEM_PERMISSIONS_FILE"
[ -s "$FILESYSTEM_PERMISSIONS_FILE" ] && FILESYSTEM_ENABLED=true || FILESYSTEM_ENABLED=false
FILESYSTEM_PATHS=$(tr '\n' ' ' <"$FILESYSTEM_PERMISSIONS_FILE")
MCP_SERVERS="sequential-thinking:@modelcontextprotocol/server-sequential-thinking fetch:@kazuph/mcp-fetch playwright:@playwright/mcp"
[ "$FILESYSTEM_ENABLED" = true ] && MCP_SERVERS="$MCP_SERVERS filesystem:@modelcontextprotocol/server-filesystem"
START_TIME=$(date +%s)
INSTALL_RESULTS=""
spin() { gum spin --spinner dot --title "$1..." -- sh -c "$2"; }
update_result() { INSTALL_RESULTS="$INSTALL_RESULTS$1:$2:$3
"; }
check_config() {
    current=$(claude mcp list 2>/dev/null | awk -F: -v s="$1" '$1==s{print substr($0,length($1)+2)}' | sed 's/^ *//')
    case "$1" in
        brave-search) expected="env BRAVE_API_KEY=$BRAVE_API_KEY npx -y @modelcontextprotocol/server-brave-search" ;;
        filesystem)
            expanded_paths=""
            for path in $FILESYSTEM_PATHS; do
                case "$path" in
                    "~") expanded_paths="$expanded_paths /home/andrius" ;;
                    "~/"*) expanded_paths="$expanded_paths /home/andrius/${path#~/}" ;;
                    *) expanded_paths="$expanded_paths $path" ;;
                esac
            done
            expected="npx -y @modelcontextprotocol/server-filesystem$expanded_paths"
            ;;
        *) expected="npx -y $2" ;;
    esac
    [ "$current" = "$expected" ]
}
add_server() {
    check_config "$1" "$2" && update_result "$1" "SUCCESS" "already configured" && return
    spin "Installing $1" "claude mcp remove '$1' 2>/dev/null; claude mcp add '$1' -- npx -y $2" && update_result "$1" "SUCCESS" "setup" || update_result "$1" "FAILED" "setup"
}
remove_unlisted() {
    listed="sequential-thinking fetch playwright brave-search git"
    [ "$FILESYSTEM_ENABLED" = true ] && listed="$listed filesystem"
    current_servers=$(claude mcp list 2>/dev/null | cut -d: -f1)
    for srv in $current_servers; do
        case " $listed " in
            *" $srv "*) ;;
            *) spin "Removing $srv" "claude mcp remove '$srv' 2>/dev/null" && update_result "$srv" "REMOVED" "removed" ;;
        esac
    done
}
missing=$(for c in node npm claude git; do command -v $c >/dev/null || echo "$c"; done)
[ -n "$missing" ] && gum style --foreground 31 "❌ Missing:$missing" && exit 1
command -v gh >/dev/null || gum style --foreground 33 "⚠️ GitHub CLI missing"
[ -n "$(git config --global user.name)" ] && [ -n "$(git config --global user.email)" ] || {
    gum style --foreground 31 "❌ Git config missing"
    exit 1
}
remove_unlisted
for srv in $MCP_SERVERS; do
    name="${srv%%:*}"
    package="${srv#*:}"
    if [ "$name" = "filesystem" ] && [ "$FILESYSTEM_ENABLED" = true ]; then
        add_server "$name" "$package $FILESYSTEM_PATHS"
    elif [ "$name" != "filesystem" ]; then
        add_server "$name" "$package"
    fi
done
if [ -n "$BRAVE_API_KEY" ]; then
    check_config "brave-search" "@modelcontextprotocol/server-brave-search" && update_result "brave-search" "SUCCESS" "already configured" || { spin "Installing brave-search" "claude mcp remove brave-search 2>/dev/null; claude mcp add brave-search -- env BRAVE_API_KEY='$BRAVE_API_KEY' npx -y @modelcontextprotocol/server-brave-search" && update_result "brave-search" "SUCCESS" "setup" || update_result "brave-search" "FAILED" "setup"; }
else
    gum style --foreground 33 "⚠️ Brave-search skipped (no API key)" && update_result "brave-search" "SKIPPED" "no API key"
fi
check_config "git" "@cyanheads/git-mcp-server" && update_result "git" "SUCCESS" "already configured" || { spin "Installing git" "npm install -g @cyanheads/git-mcp-server; claude mcp remove git 2>/dev/null; claude mcp add git -- npx -y @cyanheads/git-mcp-server" && update_result "git" "SUCCESS" "setup" || update_result "git" "FAILED" "setup"; }
END_TIME=$(date +%s)
ELAPSED=$(printf "%02d:%02d" $(((END_TIME - START_TIME) / 60)) $(((END_TIME - START_TIME) % 60)))
counts() { echo "$INSTALL_RESULTS" | grep -c "$1"; }
printf "\n┌──────────────────────────────────────────────────────────────────┐\n"
printf "│                    🎉 Installation Results                       │\n"
printf "├─────────────────────────┬─────────────┬──────────────────────────┤\n"
printf "│ Server                  │ Status      │ Action                   │\n"
printf "├─────────────────────────┼─────────────┼──────────────────────────┤\n"
echo "$INSTALL_RESULTS" | while IFS=: read -r srv status action; do
    [ -z "$srv" ] && continue
    case "$status" in
    SUCCESS) icon="✅" ;; FAILED) icon="❌" ;; SKIPPED) icon="⚠️ " ;; REMOVED) icon="🗑️ " ;; *) icon="  " ;;
    esac
    printf "│ %-23s │ %s %-8s │ %-24s │\n" "$srv" "$icon" "$status" "$action"
done
printf "├─────────────────────────┴─────────────┴──────────────────────────┤\n"
printf "│ ⏱️  %s | ✅ %s | ❌ %s | ⚠️  %s | 🗑️  %s%*s│\n" "$ELAPSED" "$(counts SUCCESS)" "$(counts FAILED)" "$(counts SKIPPED)" "$(counts REMOVED)" $((41 - ${#ELAPSED} - $(counts SUCCESS) - $(counts FAILED) - $(counts SKIPPED) - $(counts REMOVED))) ""
printf "└──────────────────────────────────────────────────────────────────┘\n"
[ "$FILESYSTEM_ENABLED" = true ] && printf "📂 %s filesystem paths\n" "$(wc -l <"$FILESYSTEM_PERMISSIONS_FILE")"
gum style --foreground 32 "🎉 Setup complete!"
gum style --foreground 33 "⚠️ Restart Claude to activate servers"
