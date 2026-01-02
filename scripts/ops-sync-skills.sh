#!/usr/bin/env bash
set -euo pipefail

# Each entry is a GitHub URL to a skill directory or SKILL.md file.
SKILL_SOURCES=(
  "https://github.com/openai/skills/tree/main/skills/.curated/gh-address-comments"
  "https://github.com/openai/skills/tree/main/skills/.curated/gh-fix-ci"
  "https://github.com/davila7/claude-code-templates/tree/main/cli-tool/components/skills/development/error-resolver"
  "https://github.com/lackeyjb/playwright-skill/tree/main/skills/playwright-skill"
  "https://github.com/davila7/claude-code-templates/tree/main/cli-tool/components/skills/development/git-commit-helper"
  "https://github.com/steveyegge/beads/tree/main/skills/beads"
)

if [[ $# -gt 0 ]]; then
  SKILL_SOURCES+=("$@")
fi

die() {
  echo "$*" >&2
  exit 1
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

resolve_installer() {
  if [[ -n "${SKILL_INSTALLER:-}" ]]; then
    [[ -f "$SKILL_INSTALLER" ]] || die "Error: skill-installer not found at $SKILL_INSTALLER"
    printf '%s\n' "$SKILL_INSTALLER"
    return 0
  fi

  local -a homes=(
    "${CODEX_HOME:-$HOME/.codex}"
    "${CLAUDE_HOME:-$HOME/.claude}"
  )

  for home in "${homes[@]}"; do
    local candidate="$home/skills/.system/skill-installer/scripts/install-skill-from-github.py"
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  die "Error: skill-installer not found (set SKILL_INSTALLER or install skill-installer)."
}

resolve_targets() {
  local raw="${SKILLS_TARGETS:-${SKILLS_CLI:-}}"
  local -a candidates=()
  local -a resolved=()

  if [[ -n "$raw" ]]; then
    raw="${raw//,/ }"
    read -ra candidates <<< "$raw"
  else
    candidates=(codex claude)
  fi

  for target in "${candidates[@]}"; do
    [[ -n "$target" ]] || continue
    case "${target,,}" in
      codex)
        if [[ -d "${CODEX_HOME:-$HOME/.codex}" ]] || have_cmd codex; then
          resolved+=("codex")
        elif [[ -n "$raw" ]]; then
          echo "Warning: codex not detected; skipping." >&2
        fi
        ;;
      claude)
        if [[ -d "${CLAUDE_HOME:-$HOME/.claude}" ]] || have_cmd claude; then
          resolved+=("claude")
        elif [[ -n "$raw" ]]; then
          echo "Warning: claude not detected; skipping." >&2
        fi
        ;;
      *)
        echo "Warning: unknown target '$target'; skipping." >&2
        ;;
    esac
  done

  if [[ ${#resolved[@]} -eq 0 ]]; then
    die "Error: neither Codex nor Claude detected."
  fi

  printf '%s\n' "${resolved[@]}"
}

target_root() {
  case "$1" in
    codex) echo "${CODEX_HOME:-$HOME/.codex}/skills" ;;
    claude) echo "${CLAUDE_HOME:-$HOME/.claude}/skills" ;;
    *) return 1 ;;
  esac
}

normalize_source() {
  local src="$1"
  src="${src%%\#*}"
  src="${src%%\?*}"
  if [[ -n "${SKILLS_REF:-}" ]]; then
    src="${src/\/tree\/main\//\/tree\/$SKILLS_REF/}"
    src="${src/\/blob\/main\//\/blob\/$SKILLS_REF/}"
  fi
  if [[ "$src" == */SKILL.md ]]; then
    src="${src%/SKILL.md}"
  elif [[ "$src" == */skill.md ]]; then
    src="${src%/skill.md}"
  fi
  printf '%s\n' "$src"
}

skill_name_from_url() {
  local url="$1"
  local path="${url#*github.com/}"
  path="${path#*/}"
  path="${path#*/}"
  if [[ "$path" == tree/* || "$path" == blob/* ]]; then
    path="${path#*/}"
    path="${path#*/}"
  fi
  path="${path%/}"
  path="${path%/SKILL.md}"
  path="${path%/skill.md}"
  printf '%s\n' "${path##*/}"
}

install_skill() {
  local dest_root="$1"
  local url="$2"

  python3 "$SKILL_INSTALLER" \
    --url "$url" \
    --dest "$dest_root"
}

remove_skill() {
  local dest_root="$1"
  local key="$2"
  local dest_dir="$dest_root/$key"

  if [[ -e "$dest_dir" ]]; then
    rm -rf "$dest_dir"
    echo "Removed $key ($dest_root)"
  fi
}

if ! have_cmd python3; then
  die "Error: python3 not found in PATH."
fi

SKILL_INSTALLER="$(resolve_installer)"
mapfile -t TARGETS < <(resolve_targets)

declare -A DESIRED_URL=()
for source in "${SKILL_SOURCES[@]}"; do
  source="$(normalize_source "$source")"
  if [[ "$source" != *github.com/* ]]; then
    die "Error: skill source must be a GitHub URL."
  fi
  skill_name="$(skill_name_from_url "$source")"
  if [[ -z "$skill_name" ]]; then
    die "Error: unable to resolve skill name from '$source'."
  fi
  DESIRED_URL["$skill_name"]="$source"
done

for target in "${TARGETS[@]}"; do
  dest_root="$(target_root "$target")" || continue
  mkdir -p "$dest_root"

  for installed in "$dest_root"/*; do
    [[ -d "$installed" ]] || continue
    base="$(basename "$installed")"
    [[ "$base" == .* ]] && continue
    [[ -f "$installed/SKILL.md" ]] || continue
    if [[ -z "${DESIRED_URL[$base]:-}" ]]; then
      remove_skill "$dest_root" "$base"
    fi
  done

  for key in "${!DESIRED_URL[@]}"; do
    dest_dir="$dest_root/$key"
    if [[ -e "$dest_dir" ]]; then
      echo "-> $key already installed in $dest_root"
      continue
    fi
    install_skill "$dest_root" "${DESIRED_URL[$key]}"
  done
done

echo "Restart Codex and Claude to pick up new skills."
