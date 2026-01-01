#!/usr/bin/env bash
set -euo pipefail

declare -A MCP_INSTALL=(
  [context7]="npx @upstash/context7-mcp"
  [git]="npx @cyanheads/git-mcp-server"
  [github]="npx @modelcontextprotocol/server-github"
  [playwright]="npx @modelcontextprotocol/server-playwright"
  [sequential-thinking]="npx @modelcontextprotocol/server-sequential-thinking"
)

declare -A MCP_ENABLE=(
  [context7]="${CONTEXT7:-1}"
  [git]="${GIT:-1}"
  [github]="${GITHUB:-0}"
  [playwright]="${PLAYWRIGHT:-0}"
  [sequential-thinking]="${SEQUENTIAL_THINKING:-0}"
)

die() {
  echo "$*" >&2
  exit 1
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

enabled() {
  local value="${1:-}"
  case "${value,,}" in 1|true|yes|on) return 0 ;; *) return 1 ;; esac
}

normalize_key() {
  local name="${1,,}"
  case "$name" in
    sequentialthinking) echo "sequential-thinking" ;;
    *) echo "$name" ;;
  esac
}

enabled_key() {
  local key="$1"
  enabled "${MCP_ENABLE[$key]:-0}"
}

resolve_clis() {
  local raw="${MCP_CLI:-}"
  local -a candidates=()
  local -a resolved=()

  if [[ -n "$raw" ]]; then
    raw="${raw//,/ }"
    read -ra candidates <<< "$raw"
  else
    candidates=(claude codex)
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
    *) return 1 ;;
  esac
}

add_server() {
  local cli="$1"
  local key="$2"
  local install; install="${MCP_INSTALL[$key]}"
  [[ -n "$install" ]] || die "Error: no install command configured for '$key'."
  read -ra cmd_parts <<< "$install"
  if [[ "${cmd_parts[0]}" == "npx" ]] && ! have_cmd npx; then
    die "Error: 'npx' not found in PATH."
  fi
  "$cli" mcp add "$key" -- "${cmd_parts[@]}" && echo "➕ Added $key ($cli)"
}

remove_server() {
  local cli="$1"
  local name="$2"
  "$cli" mcp remove "$name" && echo "➖ Removed $name ($cli)"
}

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
    local key; key="$(normalize_key "$server")"
    [[ -n "$key" ]] || continue
    [[ -v "MCP_INSTALL[$key]" ]] || continue
    current_keys["$key"]=1
    if ! enabled_key "$key"; then
      remove_server "$cli" "$server"
    fi
  done <<< "$raw"

  for key in "${!MCP_INSTALL[@]}"; do
    if enabled_key "$key" && [[ -z "${current_keys[$key]:-}" ]]; then
      add_server "$cli" "$key"
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
