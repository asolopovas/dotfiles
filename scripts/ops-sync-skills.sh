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
# Superpowers requires a repo clone and bootstrap, so it is handled separately.
SUPERPOWERS_REPO="https://github.com/obra/superpowers"

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

superpowers_block() {
    cat <<'EOF'
## Superpowers System

<EXTREMELY_IMPORTANT>
You have superpowers. Superpowers teach you new skills and capabilities. RIGHT NOW run: `~/.codex/superpowers/.codex/superpowers-codex bootstrap` and follow the instructions it returns.
</EXTREMELY_IMPORTANT>
EOF
}

ensure_superpowers_agents() {
    local codex_home="$1"
    local agents_file="$codex_home/AGENTS.md"
    local block

    block="$(superpowers_block)"

    if [[ -f "$agents_file" ]]; then
        if grep -q "superpowers-codex bootstrap" "$agents_file"; then
            return 0
        fi
        if [[ -s "$agents_file" ]]; then
            printf '\n%s\n' "$block" >> "$agents_file"
        else
            printf '%s\n' "$block" > "$agents_file"
        fi
        return 0
    fi

    mkdir -p "$codex_home"
    printf '%s\n' "$block" > "$agents_file"
}

sync_superpowers() {
    local codex_home="$1"
    local repo_url="$2"
    local repo_dir="$codex_home/superpowers"
    local cli="$repo_dir/.codex/superpowers-codex"
    local skills_output

    if ! have_cmd git; then
        die "Error: git not found in PATH."
    fi

    if [[ -d "$repo_dir/.git" ]]; then
        git -C "$repo_dir" pull --ff-only
    elif [[ -e "$repo_dir" ]]; then
        die "Error: $repo_dir exists but is not a git repository."
    else
        mkdir -p "$codex_home"
        git clone "$repo_url" "$repo_dir"
    fi

    if [[ -f "$cli" && ! -x "$cli" ]]; then
        chmod +x "$cli"
    fi

    mkdir -p "$codex_home/skills"
    ensure_superpowers_agents "$codex_home"

    if ! have_cmd node; then
        die "Error: node not found in PATH (required for superpowers)."
    fi

    if [[ ! -x "$cli" ]]; then
        die "Error: superpowers CLI not executable at $cli."
    fi

    if ! skills_output="$("$cli" find-skills)"; then
        die "Error: superpowers find-skills failed."
    fi
    if [[ -z "$skills_output" ]]; then
        die "Error: superpowers returned no skills."
    fi
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

has_skill_marker() {
    local dest_dir="$1"
    [[ -f "$dest_dir/SKILL.md" ]]
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
  if [[ "$target" == "codex" ]]; then
    sync_superpowers "${CODEX_HOME:-$HOME/.codex}" "$SUPERPOWERS_REPO"
  fi

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
      if has_skill_marker "$dest_dir"; then
        echo "-> $key already installed in $dest_root"
        continue
      fi
      echo "-> $key missing SKILL.md in $dest_root; reinstalling"
      rm -rf "$dest_dir"
    fi
    install_skill "$dest_root" "${DESIRED_URL[$key]}"
    if ! has_skill_marker "$dest_dir"; then
      die "Error: skill install missing SKILL.md at $dest_dir"
    fi
  done
done

echo "Restart Codex and Claude to pick up new skills."
