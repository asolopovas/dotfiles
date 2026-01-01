#!/usr/bin/env bash
set -euo pipefail

SKILL_INSTALLER="${CODEX_HOME:-$HOME/.codex}/skills/.system/skill-installer/scripts/install-skill-from-github.py"
if [[ ! -f "$SKILL_INSTALLER" ]]; then
  echo "Error: skill-installer not found at $SKILL_INSTALLER" >&2
  exit 1
fi

SKILLS=(
  gh-address-comments
  gh-fix-ci
)

REPO="openai/skills"
REF="${SKILLS_REF:-main}"

install_skill() {
  local dest_root="$1"
  local skill="$2"
  local dest_dir="$dest_root/$skill"

  if [[ -e "$dest_dir" ]]; then
    echo "-> $skill already installed in $dest_root"
    return 0
  fi

  python3 "$SKILL_INSTALLER" \
    --repo "$REPO" \
    --ref "$REF" \
    --path "skills/.curated/$skill" \
    --dest "$dest_root"
}

TARGETS=()
if [[ -d "${CODEX_HOME:-$HOME/.codex}" ]]; then
  TARGETS+=("codex")
elif command -v codex >/dev/null 2>&1; then
  TARGETS+=("codex")
fi

if [[ -d "${CLAUDE_HOME:-$HOME/.claude}" ]]; then
  TARGETS+=("claude")
elif command -v claude >/dev/null 2>&1; then
  TARGETS+=("claude")
fi

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  echo "Error: neither Codex nor Claude detected." >&2
  exit 1
fi

for target in "${TARGETS[@]}"; do
  case "$target" in
    codex) dest_root="${CODEX_HOME:-$HOME/.codex}/skills" ;;
    claude) dest_root="${CLAUDE_HOME:-$HOME/.claude}/skills" ;;
    *) continue ;;
  esac

  mkdir -p "$dest_root"
  for skill in "${SKILLS[@]}"; do
    install_skill "$dest_root" "$skill"
  done
done

echo "Restart Codex and Claude to pick up new skills."
