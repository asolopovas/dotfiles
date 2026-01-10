#!/usr/bin/env bash
set -euo pipefail

# name|install command
declare -A SERVERS=(
  [context7]="npx @upstash/context7-mcp"
  [git]="npx @cyanheads/git-mcp-server"
  [github]="npx @modelcontextprotocol/server-github"
  [chrome-devtools]="npx chrome-devtools-mcp --browser-url=http://127.0.0.1:9222"
)

CONFIG_FILE="${OPENCODE_CONFIG:-$HOME/.config/opencode/opencode.jsonc}"

add_server() {
  local name="$1" cmd="$2"
  shift 2
  read -ra cmd_parts <<< "$cmd"

  local entry
  entry=$(jq -n --arg name "$name" \
    --argjson cmd "$(printf '%s\n' "${cmd_parts[@]}" | jq -R . | jq -s .)" \
    '{($name): {type: "local", command: $cmd, enabled: true}}')

  jq --argjson entry "$entry" '.mcp //= {} | .mcp *= $entry' "$CONFIG_FILE" \
    > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
}

remove_server() {
  local name="$1"
  jq --arg name "$name" 'del(.mcp[$name])' "$CONFIG_FILE" \
    > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
}

# get current servers from config
current=$(jq -r '.mcp | keys[]' "$CONFIG_FILE" 2>/dev/null || true)

# remove servers not in SERVERS
for name in $current; do
  [[ -v SERVERS[$name] ]] || remove_server "$name"
done

# add/update servers
for name in "${!SERVERS[@]}"; do
  add_server "$name" "${SERVERS[$name]}"
done

echo "✅ MCP sync complete"
