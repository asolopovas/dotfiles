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
  [github]=$(want_enabled "${GITHUB:-}" && echo 1 || echo 0)
  [playwright]=$(want_enabled "${PLAYWRIGHT:-}" && echo 1 || echo 0)
  [sequential-thinking]=$(want_enabled "${SEQUENTIAL_THINKING:-}" && echo 1 || echo 0)
)

command -v claude >/dev/null || { echo "Error: 'claude' CLI not found in PATH." >&2; exit 1; }
command -v npx >/dev/null    || { echo "Error: 'npx' not found in PATH." >&2; exit 1; }

gh_ok=false
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then gh_ok=true; fi

pkg_for() {
  case "$1" in
    context7)            echo "@upstash/context7-mcp" ;;
    git)                 echo "@cyanheads/git-mcp-server" ;;
    github)              echo "@modelcontextprotocol/server-github" ;;
    playwright)          echo "@playwright/mcp" ;;
    sequential-thinking) echo "@modelcontextprotocol/server-sequential-thinking" ;;
    *)                   echo "@modelcontextprotocol/server-$1" ;;
  esac
}

mapfile -t CURRENT < <(claude mcp list 2>/dev/null | awk -F: '/^[a-z0-9-]+:/{print $1}')

in_current() {
  local s="$1"
  local x
  for x in "${CURRENT[@]:-}"; do [[ "$x" == "$s" ]] && return 0; done
  return 1
}

add_server() {
  local s="$1"
  # Special case: github requires gh auth
  if [[ "$s" == "github" && "$gh_ok" != true ]]; then
    echo "↪︎ Skipping github (gh not installed or not authenticated)."
    return 0
  fi
  local pkg; pkg="$(pkg_for "$s")"
  # Build args without eval
  claude mcp add "$s" -- npx "$pkg" && echo "➕ Added $s"
}

remove_server() {
  local s="$1"
  claude mcp remove "$s" && echo "➖ Removed $s"
}

for s in "${CURRENT[@]:-}"; do
  if [[ -z "${WANT[$s]:-}" || "${WANT[$s]}" != "1" ]]; then
    remove_server "$s"
  fi
done

for s in "${!WANT[@]}"; do
  [[ "${WANT[$s]}" == "1" ]] || continue
  in_current "$s" || add_server "$s"
done

if command -v tput >/dev/null 2>&1 && [[ -t 1 ]]; then
  printf "%s\n" "$(tput setaf 2)✅ MCP sync complete$(tput sgr0)"
else
  echo "✅ MCP sync complete"
fi
