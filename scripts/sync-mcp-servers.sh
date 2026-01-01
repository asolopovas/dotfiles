#!/usr/bin/env bash
set -euo pipefail

die() {
  echo "$*" >&2
  exit 1
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

want_enabled() {
  local v="${1:-}"
  [[ -z "$v" ]] && return 0
  case "${v,,}" in 1|true|yes|on) return 0 ;; *) return 1 ;; esac
}

declare -A WANT=(
  [context7]=$(want_enabled "${CONTEXT7:-}" && echo 1 || echo 0)
  [git]=$(want_enabled "${GIT:-}" && echo 1 || echo 0)
)

resolve_clis() {
  local -a candidates=()
  local -a resolved=()
  if [[ -n "${MCP_CLI:-}" ]]; then
    local raw="${MCP_CLI//,/ }"
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
  have_cmd npx || die "Error: 'npx' not found in PATH."
  "$cli" mcp add "$s" -- npx "$pkg" && echo "➕ Added $s ($cli)"
}

remove_server() {
  local cli="$1"
  local s="$2"
  "$cli" mcp remove "$s" && echo "➖ Removed $s ($cli)"
}

mapfile -t CLIS < <(resolve_clis)

for cli in "${CLIS[@]}"; do
  if ! CURRENT_RAW="$(list_servers "$cli")"; then
    echo "Warning: '$cli mcp list' failed; skipping." >&2
    continue
  fi
  mapfile -t CURRENT <<< "$CURRENT_RAW"
  declare -A CURRENT_KEYS=()
  for s in "${CURRENT[@]:-}"; do
    [[ -n "$s" ]] || continue
    key="$(key_for_name "$s")"
    [[ -n "$key" ]] || continue
    CURRENT_KEYS["$key"]=1
    if [[ "${WANT[$key]:-0}" != "1" ]]; then
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
