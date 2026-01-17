#!/usr/bin/env bash
set -euo pipefail

# name|install command
declare -A SERVERS=(
  [context7]="npx @upstash/context7-mcp"
  [git]="npx @cyanheads/git-mcp-server"
  [github]="npx @modelcontextprotocol/server-github"
  [chrome-devtools]="npx -y chrome-devtools-mcp --browser-url=http://127.0.0.1:9222"
)

CONFIG_FILE="${OPENCODE_CONFIG:-$HOME/.config/opencode/opencode.json}"
CODEX_CONFIG="${CODEX_CONFIG:-$HOME/.codex/config.toml}"

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

codex_block_for() {
    local name="$1"
    case "$name" in
        Context7)
            cat <<'EOF'
[mcp_servers.Context7]
command = "npx"
args = ["-y", "@upstash/context7-mcp@latest"]
EOF
            ;;
        Git)
            cat <<'EOF'
[mcp_servers.Git]
command = "npx"
args = ["-y", "@cyanheads/git-mcp-server@latest"]
EOF
            ;;
        github)
            cat <<'EOF'
[mcp_servers.github]
command = "npx"
args = ["@modelcontextprotocol/server-github"]
EOF
            ;;
        chrome-devtools)
            cat <<'EOF'
[mcp_servers.chrome-devtools]
command = "npx"
args = ["-y", "chrome-devtools-mcp", "--browser-url=http://127.0.0.1:9222"]
sandbox_permissions = ["network-access"]
EOF
            ;;
        *)
            return 1
            ;;
    esac
}

codex_upsert_server() {
    local name="$1"
    local tmp

    [[ -f "$CODEX_CONFIG" ]] || printf '\n' > "$CODEX_CONFIG"

    tmp="$(mktemp)"
    awk -v section="mcp_servers.${name}" '
        BEGIN { in_section = 0 }
        /^\[/ {
            if (in_section == 1) { in_section = 0 }
            if ($0 == "[" section "]") { in_section = 1; next }
        }
        in_section == 0 { print }
    ' "$CODEX_CONFIG" > "$tmp"

    cat "$tmp" > "$CODEX_CONFIG"
    rm -f "$tmp"

    if ! codex_block_for "$name" >> "$CODEX_CONFIG"; then
        return 1
    fi
    printf '\n' >> "$CODEX_CONFIG"
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

codex_upsert_server "Context7"
codex_upsert_server "Git"
codex_upsert_server "github"
codex_upsert_server "chrome-devtools"

echo "✅ MCP sync complete (opencode + codex)"
