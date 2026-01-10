#!/usr/bin/env bash
set -euo pipefail

# Each entry: name|install command (the command is passed after `--` to `mcp add`).
MCP_SERVERS=(
  "context7|npx @upstash/context7-mcp"
  "git|npx @cyanheads/git-mcp-server"
  "github|npx @modelcontextprotocol/server-github"
#   "playwright|npx @modelcontextprotocol/server-playwright"
#   "sequential-thinking|npx @modelcontextprotocol/server-sequential-thinking"
)

if [[ $# -gt 0 ]]; then
  MCP_SERVERS+=("$@")
fi

die() {
  echo "$*" >&2
  exit 1
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

normalize_key() {
  local name="${1,,}"
  case "$name" in
    sequentialthinking) echo "sequential-thinking" ;;
    *) echo "$name" ;;
  esac
}

parse_entry() {
  local entry="$1"
  local name
  local cmd

  if [[ "$entry" == *"|"* ]]; then
    name="${entry%%|*}"
    cmd="${entry#*|}"
  elif [[ "$entry" == *"="* ]]; then
    name="${entry%%=*}"
    cmd="${entry#*=}"
  else
    die "Error: invalid MCP entry '$entry'. Use 'name|command'."
  fi

  name="$(trim "$name")"
  cmd="$(trim "$cmd")"
  name="$(normalize_key "$name")"

  if [[ -z "$name" || -z "$cmd" ]]; then
    die "Error: invalid MCP entry '$entry'."
  fi

  ENTRY_NAME="$name"
  ENTRY_CMD="$cmd"
}

resolve_clis() {
  local raw="${MCP_CLI:-}"
  local -a candidates=()
  local -a resolved=()

  if [[ -n "$raw" ]]; then
    raw="${raw//,/ }"
    read -ra candidates <<< "$raw"
  else
    candidates=(claude codex opencode)
  fi

  for cli in "${candidates[@]}"; do
    [[ -n "$cli" ]] || continue
    if have_cmd "$cli"; then
      resolved+=("$cli")
    elif [[ -n "${MCP_CLI:-}" ]]; then
      echo "Warning: '$cli' not found in PATH; skipping." >&2
    fi
  done

  if [[ ${#resolved[@]} -eq 0 ]]; then
    die "Error: no supported MCP CLI found in PATH."
  fi

  printf '%s\n' "${resolved[@]}"
}

list_servers() {
  local cli="$1"
  case "$cli" in
    claude) claude mcp list 2>/dev/null | awk -F: '/^[a-z0-9-]+:/{print $1}' ;;
    codex) codex mcp list 2>/dev/null | awk 'NR>1 && $1 != "" {print $1}' ;;
    opencode) opencode mcp list 2>/dev/null | grep -oP '^\s*[●▪]\s+[✓✗]\s+\K[a-z0-9-]+' ;;
    *) return 1 ;;
  esac
}

add_server() {
  local cli="$1"
  local key="$2"
  local install="$3"
  read -ra cmd_parts <<< "$install"
  if [[ "${cmd_parts[0]}" == "npx" ]] && ! have_cmd npx; then
    die "Error: 'npx' not found in PATH."
  fi

  if [[ "$cli" == "opencode" ]]; then
    add_opencode_server "$key" "$install"
  else
    "$cli" mcp add "$key" -- "${cmd_parts[@]}" && echo "➕ Added $key ($cli)"
  fi
}

remove_server() {
  local cli="$1"
  local name="$2"

  if [[ "$cli" == "opencode" ]]; then
    remove_opencode_server "$name"
  else
    "$cli" mcp remove "$name" && echo "➖ Removed $name ($cli)"
  fi
}

get_opencode_config() {
  local config_file="${OPENCODE_CONFIG:-$HOME/.config/opencode/opencode.jsonc}"
  if [[ ! -f "$config_file" ]]; then
    echo "{}" > "$config_file"
  fi
  echo "$config_file"
}

add_opencode_server() {
  local key="$1"
  local install="$2"
  local config_file
  config_file="$(get_opencode_config)"
  read -ra cmd_parts <<< "$install"

  local json_entry
  json_entry=$(jq -n \
    --arg type "local" \
    --argjson cmd "$(printf '%s\n' "${cmd_parts[@]}" | jq -R . | jq -s .)" \
    --argjson enabled true \
    '{type: $type, command: $cmd, enabled: $enabled}')

  jq --arg key "$key" --argjson entry "$json_entry" \
    '.mcp //= {} | .mcp[$key] = $entry' \
    "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"

  echo "➕ Added $key ($cli via config)"
}

remove_opencode_server() {
  local name="$1"
  local config_file
  config_file="$(get_opencode_config)"

  if jq -e --arg key "$name" '.mcp | has($key)' "$config_file" >/dev/null 2>&1; then
    jq --arg key "$name" 'del(.mcp[$key])' "$config_file" > "$config_file.tmp" && \
      mv "$config_file.tmp" "$config_file"
    echo "➖ Removed $name (opencode via config)"
  fi
}

declare -A DESIRED_CMD=()
for entry in "${MCP_SERVERS[@]}"; do
  parse_entry "$entry"
  DESIRED_CMD["$ENTRY_NAME"]="$ENTRY_CMD"
done

mapfile -t CLIS < <(resolve_clis)

sync_cli() {
  local cli="$1"
  local raw
  declare -A current_keys=()

  if ! raw="$(list_servers "$cli")"; then
    echo "Warning: '$cli mcp list' failed; skipping." >&2
    return
  fi

  while IFS= read -r server; do
    [[ -n "$server" ]] || continue
    local key
    key="$(normalize_key "$server")"
    if [[ -z "${DESIRED_CMD[$key]:-}" ]]; then
      remove_server "$cli" "$server"
      continue
    fi
    current_keys["$key"]=1
  done <<< "$raw"

  for key in "${!DESIRED_CMD[@]}"; do
    if [[ -z "${current_keys[$key]:-}" ]]; then
      add_server "$cli" "$key" "${DESIRED_CMD[$key]}"
    fi
  done
}

for cli in "${CLIS[@]}"; do
  sync_cli "$cli"
done

if command -v tput >/dev/null 2>&1 && [[ -t 1 ]]; then
  printf "%s\n" "$(tput setaf 2)✅ MCP sync complete$(tput sgr0)"
else
  echo "✅ MCP sync complete"
fi
