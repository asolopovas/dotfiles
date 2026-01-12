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
CODEX_CONFIG="${CODEX_CONFIG:-${CODEX_HOME:-$HOME/.codex}/config.toml}"

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

build_codex_block() {
  local name cmd
  local -a cmd_parts
  local toml_command toml_args

  for name in $(printf '%s\n' "${!SERVERS[@]}" | sort); do
    cmd="${SERVERS[$name]}"
    read -ra cmd_parts <<< "$cmd"
    toml_command=$(printf '%s' "${cmd_parts[0]}" | jq -R .)
    toml_args=$(printf '%s\n' "${cmd_parts[@]:1}" | jq -R . | jq -s -c .)

    printf '[mcp_servers.%s]\n' "$name"
    printf 'command = %s\n' "$toml_command"
    printf 'args = %s\n\n' "$toml_args"
  done
}

sync_codex_config() {
  local config="$CODEX_CONFIG"
  local config_dir tmp

  config_dir=$(dirname "$config")
  mkdir -p "$config_dir"
  tmp="${config}.tmp"

  if [[ -f "$config" ]]; then
    awk '
      BEGIN { skip = 0 }
      /^\[mcp_servers\./ { skip = 1; next }
      /^\[.*\]/ {
        if (skip == 1) { skip = 0; print; next }
      }
      skip == 0 { print }
    ' "$config" > "$tmp"
  else
    : > "$tmp"
  fi

  if [[ -s "$tmp" ]]; then
    printf '\n' >> "$tmp"
  fi
  build_codex_block >> "$tmp"
  mv "$tmp" "$config"
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

sync_codex_config

echo "✅ MCP sync complete"
