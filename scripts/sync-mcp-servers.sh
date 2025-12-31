#!/usr/bin/env bash
set -euo pipefail

want_enabled() {
  local v="${1:-}"
  [[ -z "$v" ]] && return 0
  case "${v,,}" in 1|true|yes|on) return 0 ;; *) return 1 ;; esac
}

declare -A WANT=(
  [context7]=$(want_enabled "${CONTEXT7:-}" && echo 1 || echo 0)
  [git]=$(want_enabled "${GIT:-}" && echo 1 || echo 0)
)

CLIS=()
if [[ -n "${MCP_CLI:-}" ]]; then
  CLIS+=("$MCP_CLI")
else
  command -v claude >/dev/null 2>&1 && CLIS+=(claude)
  command -v codex >/dev/null 2>&1 && CLIS+=(codex)
fi
if [[ ${#CLIS[@]} -eq 0 ]]; then
  echo "Error: neither 'claude' nor 'codex' CLI found in PATH." >&2
  exit 1
fi
command -v npx >/dev/null 2>&1 || { echo "Error: 'npx' not found in PATH." >&2; exit 1; }

pkg_for() {
  case "$1" in
    context7)            echo "@upstash/context7-mcp" ;;
    git)                 echo "@cyanheads/git-mcp-server" ;;
    *)                   echo "@modelcontextprotocol/server-$1" ;;
  esac
}

key_for_name() {
  local name="${1,,}"
  case "$name" in
    context7) echo "context7" ;;
    git) echo "git" ;;
    github) echo "github" ;;
    playwright) echo "playwright" ;;
    sequentialthinking|sequential-thinking) echo "sequential-thinking" ;;
    *) echo "" ;;
  esac
}

list_servers() {
  local cli="$1"
  case "$cli" in
    claude) claude mcp list 2>/dev/null | awk -F: '/^[a-z0-9-]+:/{print $1}' ;;
    codex)  codex mcp list 2>/dev/null | awk 'NR>1 && $1 != "" {print $1}' ;;
    *) return 1 ;;
  esac
}

add_server() {
  local cli="$1"
  local s="$2"
  local pkg; pkg="$(pkg_for "$s")"
  # Build args without eval
  "$cli" mcp add "$s" -- npx "$pkg" && echo "➕ Added $s ($cli)"
}

remove_server() {
  local cli="$1"
  local s="$2"
  "$cli" mcp remove "$s" && echo "➖ Removed $s ($cli)"
}

for cli in "${CLIS[@]}"; do
  mapfile -t CURRENT < <(list_servers "$cli")
  declare -A CURRENT_KEYS=()
  for s in "${CURRENT[@]:-}"; do
    [[ -n "$s" ]] || continue
    key="$(key_for_name "$s")"
    [[ -n "$key" ]] && CURRENT_KEYS["$key"]=1
    if [[ -n "$key" && ( ! -v "WANT[$key]" || "${WANT[$key]:-0}" != "1" ) ]]; then
      remove_server "$cli" "$s"
    fi
  done

  for key in "${!WANT[@]}"; do
    [[ "${WANT[$key]}" == "1" ]] || continue
    [[ -v "CURRENT_KEYS[$key]" ]] || add_server "$cli" "$key"
  done
done

if command -v tput >/dev/null 2>&1 && [[ -t 1 ]]; then
  printf "%s\n" "$(tput setaf 2)✅ MCP sync complete$(tput sgr0)"
else
  echo "✅ MCP sync complete"
fi
