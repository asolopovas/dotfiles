#!/bin/sh
. "$HOME/dotfiles/globals.sh"
[ -f "$HOME/.env" ] && . "$HOME/.env"
FILESYSTEM_PERMISSIONS_FILE="$HOME/.mcp_folder_permissions"
[ -f "$FILESYSTEM_PERMISSIONS_FILE" ] || touch "$FILESYSTEM_PERMISSIONS_FILE"
[ -s "$FILESYSTEM_PERMISSIONS_FILE" ] && FILESYSTEM_ENABLED=true || FILESYSTEM_ENABLED=false
FILESYSTEM_PATHS=$(tr '\n' ' ' < "$FILESYSTEM_PERMISSIONS_FILE")
MCP_SERVERS="sequential-thinking:@modelcontextprotocol/server-sequential-thinking fetch:@kazuph/mcp-fetch browser-tools:@agentdeskai/browser-tools-mcp@1.2.1 playwright:@playwright/mcp"
[ "$FILESYSTEM_ENABLED" = true ] && MCP_SERVERS="$MCP_SERVERS filesystem:@modelcontextprotocol/server-filesystem"
START_TIME=$(date +%s)
INSTALL_RESULTS=""
spin() { gum spin --spinner dot --title "$1..." -- sh -c "$2"; }
update_result() { INSTALL_RESULTS="$INSTALL_RESULTS$1:$2:$3
"; }
check_config() { current=$(claude mcp list 2>/dev/null | awk -F: -v s="$1" '$1==s{print substr($0,length($1)+2)}' | sed 's/^ *//'); [ "$current" = "npx -y $2" ]; }
add_server() { check_config "$1" "$2" && update_result "$1" "SUCCESS" "already configured" && return; spin "Installing $1" "claude mcp remove '$1' 2>/dev/null; claude mcp add '$1' -- npx -y $2" && update_result "$1" "SUCCESS" "setup" || update_result "$1" "FAILED" "setup"; }
remove_unlisted() {
  listed=$(echo "$MCP_SERVERS brave-search git filesystem" | tr ' ' '\n')
  claude mcp list 2>/dev/null | cut -d: -f1 | while read -r srv; do
    echo "$listed" | grep -qxF "$srv" || { spin "Removing $srv" "claude mcp remove '$srv' 2>/dev/null" && update_result "$srv" "REMOVED" "removed"; }
  done
}
missing=$(for c in node npm claude git; do command -v $c >/dev/null || echo "$c"; done)
[ -n "$missing" ] && gum style --foreground 31 "❌ Missing:$missing" && exit 1
command -v gh >/dev/null || gum style --foreground 33 "⚠️ GitHub CLI missing"
[ -n "$(git config --global user.name)" ] && [ -n "$(git config --global user.email)" ] || { gum style --foreground 31 "❌ Git config missing"; exit 1; }
remove_unlisted
for srv in $MCP_SERVERS; do name="${srv%%:*}"; package="${srv#*:}"; [ "$name" = "filesystem" ] && [ "$FILESYSTEM_ENABLED" = true ] && add_server "$name" "$package $FILESYSTEM_PATHS" || add_server "$name" "$package"; done
if [ -n "$BRAVE_API_KEY" ]; then
  brave_cmd="env BRAVE_API_KEY=$BRAVE_API_KEY npx -y @modelcontextprotocol/server-brave-search"
  check_config "brave-search" "$brave_cmd" && update_result "brave-search" "SUCCESS" "already configured" || { spin "Installing brave-search" "claude mcp remove brave-search 2>/dev/null; claude mcp add brave-search -- $brave_cmd" && update_result "brave-search" "SUCCESS" "setup" || update_result "brave-search" "FAILED" "setup"; }
else
  gum style --foreground 33 "⚠️ Brave-search skipped (no API key)" && update_result "brave-search" "SKIPPED" "no API key"
fi
check_config "git" "@cyanheads/git-mcp-server" && update_result "git" "SUCCESS" "already configured" || { spin "Installing git" "npm install -g @cyanheads/git-mcp-server; claude mcp remove git 2>/dev/null; claude mcp add git -- npx -y @cyanheads/git-mcp-server" && update_result "git" "SUCCESS" "setup" || update_result "git" "FAILED" "setup"; }
END_TIME=$(date +%s)
ELAPSED=$(printf "%02d:%02d" $(((END_TIME-START_TIME)/60)) $(((END_TIME-START_TIME)%60)))
counts() { echo "$INSTALL_RESULTS" | grep -c "$1"; }
printf "\n┌─────────────────────────────────────────────────────────────────┐\n"
printf "│                    🎉 Installation Results                      │\n"
printf "├─────────────────────────┬────────────┬──────────────────────────┤\n"
printf "│ Server                  │ Status     │ Action                   │\n"
printf "├─────────────────────────┼────────────┼──────────────────────────┤\n"
echo "$INSTALL_RESULTS" | while IFS=: read -r srv status action; do
  [ -z "$srv" ] && continue
  case "$status" in
    SUCCESS) icon="✅" ;; FAILED) icon="❌" ;; SKIPPED) icon="⚠️ " ;; REMOVED) icon="🗑️ " ;; *) icon="  " ;;
  esac
  printf "│ %-23s │ %s %-8s │ %-24s │\n" "$srv" "$icon" "$status" "$action"
done
printf "├─────────────────────────┴────────────┴──────────────────────────┤\n"
printf "│ ⏱️  %s | ✅ %s | ❌ %s | ⚠️  %s | 🗑️  %s%*s│\n" "$ELAPSED" "$(counts SUCCESS)" "$(counts FAILED)" "$(counts SKIPPED)" "$(counts REMOVED)" $((47-${#ELAPSED}-$(counts SUCCESS)-$(counts FAILED)-$(counts SKIPPED)-$(counts REMOVED))) ""
printf "└─────────────────────────────────────────────────────────────────┘\n"
[ "$FILESYSTEM_ENABLED" = true ] && printf "📂 %s filesystem paths\n" "$(wc -l < "$FILESYSTEM_PERMISSIONS_FILE")"
gum style --foreground 32 "🎉 Setup complete!"
gum style --foreground 33 "⚠️ Restart Claude to activate servers"