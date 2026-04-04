#!/usr/bin/env bats

# ---------------------------------------------------------------------------
# Unit tests for sync-ai.sh — skill installation, symlink management,
# MCP server sync, and target resolution.
# Runs locally, no Docker, no network, no sudo.
# ---------------------------------------------------------------------------

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    export FAKE_HOME="$(mktemp -d)"
    export TMPDIR="$(mktemp -d)"
    export FAKE_BIN="$TMPDIR/fake-bin"
    mkdir -p "$FAKE_BIN"

    # Mock git: clone creates dir, sparse-checkout creates a SKILL.md
    cat > "$FAKE_BIN/git" <<'MOCK'
#!/bin/bash
case "$1" in
    clone) mkdir -p "${@: -1}" ;;
    -C)    repo="$2"; shift 4; mkdir -p "$repo/$1"
           printf -- '---\nname: %s\ndescription: Test\n---\n' "$(basename "$1")" \
               > "$repo/$1/SKILL.md" ;;
esac
MOCK
    chmod +x "$FAKE_BIN/git"

    # Minimal mocks for commands the script checks
    printf '#!/bin/sh\nexit 0\n' > "$FAKE_BIN/python3" && chmod +x "$FAKE_BIN/python3"
    printf '#!/bin/sh\ncase "$1" in mcp) case "$2" in list) ;; get) exit 1;; esac;; esac\n' \
        > "$FAKE_BIN/claude" && chmod +x "$FAKE_BIN/claude"

    # Use real jq if available
    if command -v jq &>/dev/null; then
        ln -s "$(command -v jq)" "$FAKE_BIN/jq"
    fi

    # Fake CLI home directories
    mkdir -p "$FAKE_HOME"/{.claude,.codex,.config/opencode,.agents}

    export PATH="$FAKE_BIN:$PATH"
    export HOME="$FAKE_HOME"
    export AGENTS_SKILLS_DIR="$FAKE_HOME/.agents/skills"
    export CODEX_HOME="$FAKE_HOME/.codex"
    export CLAUDE_HOME="$FAKE_HOME/.claude"
    export OPENCODE_HOME="$FAKE_HOME/.config/opencode"
    export DOTFILES_DIR="$REPO_DIR"
    export CODEX_CONFIG="$FAKE_HOME/.codex/config.toml"
    export AGENTS_CONFIG="$TMPDIR/empty-agents.conf"
    touch "$AGENTS_CONFIG"

    # Source script functions (strip main invocation)
    source <(sed 's/^main "\$@"$//' "$REPO_DIR/scripts/sync-ai.sh")
}

teardown() {
    rm -rf "$FAKE_HOME" "$TMPDIR"
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

assert_skills_symlink() {
    local path="$1"
    [ -L "$path" ]
    [[ "$(readlink "$path")" == "$AGENTS_SKILLS_DIR" ]]
}

create_fake_skill() {
    local dir="$AGENTS_SKILLS_DIR/$1"
    mkdir -p "$dir"
    printf -- '---\nname: %s\ndescription: Test\n---\n' "$1" > "$dir/SKILL.md"
}

sync_ai_run() {
    bash "$REPO_DIR/scripts/sync-ai.sh" "$@"
}

# =====================================================================
#  ensure_skill_symlink
# =====================================================================

@test "ensure_skill_symlink: creates new symlink" {
    mkdir -p "$AGENTS_SKILLS_DIR"
    ensure_skill_symlink "$FAKE_HOME/.claude/skills"
    assert_skills_symlink "$FAKE_HOME/.claude/skills"
}

@test "ensure_skill_symlink: replaces existing directory" {
    mkdir -p "$AGENTS_SKILLS_DIR" "$FAKE_HOME/.codex/skills/old"
    ensure_skill_symlink "$FAKE_HOME/.codex/skills"
    assert_skills_symlink "$FAKE_HOME/.codex/skills"
}

@test "ensure_skill_symlink: replaces wrong symlink target" {
    mkdir -p "$AGENTS_SKILLS_DIR"
    ln -s /wrong/target "$FAKE_HOME/.claude/skills"
    ensure_skill_symlink "$FAKE_HOME/.claude/skills"
    assert_skills_symlink "$FAKE_HOME/.claude/skills"
}

@test "ensure_skill_symlink: idempotent when correct" {
    mkdir -p "$AGENTS_SKILLS_DIR"
    ln -s "$AGENTS_SKILLS_DIR" "$FAKE_HOME/.claude/skills"
    run ensure_skill_symlink "$FAKE_HOME/.claude/skills"
    [[ "$status" -eq 0 ]]
    assert_skills_symlink "$FAKE_HOME/.claude/skills"
}

@test "ensure_skill_symlink: creates parent directories" {
    mkdir -p "$AGENTS_SKILLS_DIR"
    rm -rf "$FAKE_HOME/.codex"
    ensure_skill_symlink "$FAKE_HOME/.codex/skills"
    [ -L "$FAKE_HOME/.codex/skills" ]
}

# =====================================================================
#  sync_skills
# =====================================================================

@test "sync_skills: creates canonical dir and claude/codex symlinks" {
    TARGETS=(claude codex)
    sync_skills
    [ -d "$AGENTS_SKILLS_DIR" ]
    assert_skills_symlink "$FAKE_HOME/.claude/skills"
    assert_skills_symlink "$FAKE_HOME/.codex/skills"
}

@test "sync_skills: does NOT create opencode symlink" {
    TARGETS=(opencode)
    mkdir -p "$FAKE_HOME/.config/opencode/skills"
    sync_skills
    [ ! -L "$FAKE_HOME/.config/opencode/skills" ]
}

@test "sync_skills: removes unwanted skills, preserves dotfiles" {
    TARGETS=(claude)
    create_fake_skill "unwanted-skill"
    mkdir -p "$AGENTS_SKILLS_DIR/.system/installer"
    touch "$AGENTS_SKILLS_DIR/.system/installer/test"

    sync_skills

    [ ! -d "$AGENTS_SKILLS_DIR/unwanted-skill" ]
    [ -d "$AGENTS_SKILLS_DIR/.system" ]
}

# =====================================================================
#  Symlink visibility — all CLIs see same content
# =====================================================================

@test "symlinks: all CLIs see identical skill content" {
    create_fake_skill "shared-skill"
    ensure_skill_symlink "$FAKE_HOME/.claude/skills"
    ensure_skill_symlink "$FAKE_HOME/.codex/skills"

    local expected
    expected=$(cat "$AGENTS_SKILLS_DIR/shared-skill/SKILL.md")
    [[ "$(cat "$FAKE_HOME/.claude/skills/shared-skill/SKILL.md")" == "$expected" ]]
    [[ "$(cat "$FAKE_HOME/.codex/skills/shared-skill/SKILL.md")" == "$expected" ]]
}

# =====================================================================
#  Target resolution
# =====================================================================

@test "resolve_targets: detects existing CLI dirs" {
    for cli in claude codex opencode; do
        TARGETS=()
        export SYNC_TARGETS="$cli"
        resolve_targets
        [[ " ${TARGETS[*]} " == *" $cli "* ]]
    done
}

@test "resolve_targets: warns on unknown target" {
    TARGETS=()
    export SYNC_TARGETS="claude,bogus"
    run resolve_targets
    [[ "$output" == *"unknown"* ]] || [[ "$output" == *"Warning"* ]]
}

# =====================================================================
#  cli_home
# =====================================================================

@test "cli_home: returns correct paths for all CLIs" {
    [[ "$(cli_home claude)"   == "$FAKE_HOME/.claude" ]]
    [[ "$(cli_home codex)"    == "$FAKE_HOME/.codex" ]]
    [[ "$(cli_home opencode)" == "$FAKE_HOME/.config/opencode" ]]
}

@test "cli_home: fails for unknown CLI" {
    run cli_home notreal
    [[ "$status" -ne 0 ]]
}

# =====================================================================
#  URL parsing helpers
# =====================================================================

@test "skill_name_from_url: extracts leaf name from various URLs" {
    [[ "$(skill_name_from_url "https://github.com/o/r/tree/main/skills/my-skill")" == "my-skill" ]]
    [[ "$(skill_name_from_url "https://github.com/davila7/claude-code-templates/tree/main/cli-tool/components/skills/development/error-resolver")" == "error-resolver" ]]
    [[ "$(skill_name_from_url "https://github.com/o/r/tree/main/skills/s/SKILL.md")" == "s" ]]
}

@test "normalize_skill_source: strips query params" {
    [[ "$(normalize_skill_source "https://github.com/o/r/tree/main/s/t?tab=readme#x")" == "https://github.com/o/r/tree/main/s/t" ]]
}

@test "normalize_skill_source: respects SKILLS_REF override" {
    export SKILLS_REF="v2.0"
    [[ "$(normalize_skill_source "https://github.com/o/r/tree/main/s/t")" == "https://github.com/o/r/tree/v2.0/s/t" ]]
}

# =====================================================================
#  AGENTS_SKILLS_DIR config
# =====================================================================

@test "config: AGENTS_SKILLS_DIR defaults to ~/.agents/skills" {
    unset AGENTS_SKILLS_DIR
    export HOME="$FAKE_HOME"
    source <(sed 's/^main "\$@"$//' "$REPO_DIR/scripts/sync-ai.sh")
    [[ "$AGENTS_SKILLS_DIR" == "$FAKE_HOME/.agents/skills" ]]
}

@test "config: AGENTS_SKILLS_DIR respects env override" {
    export AGENTS_SKILLS_DIR="/custom/path"
    source <(sed 's/^main "\$@"$//' "$REPO_DIR/scripts/sync-ai.sh")
    [[ "$AGENTS_SKILLS_DIR" == "/custom/path" ]]
}

# =====================================================================
#  resolve_skill_installer
# =====================================================================

@test "resolve_skill_installer: finds installer in canonical dir" {
    mkdir -p "$AGENTS_SKILLS_DIR/.system/skill-installer/scripts"
    touch "$AGENTS_SKILLS_DIR/.system/skill-installer/scripts/install-skill-from-github.py"
    [[ "$(resolve_skill_installer)" == *".agents/skills/.system/skill-installer/scripts/install-skill-from-github.py" ]]
}

@test "resolve_skill_installer: respects SKILL_INSTALLER env" {
    local fake="$TMPDIR/my-installer.py" && touch "$fake"
    export SKILL_INSTALLER="$fake"
    [[ "$(resolve_skill_installer)" == "$fake" ]]
}

# =====================================================================
#  MCP: codex config.toml sync
# =====================================================================

@test "mcp_codex_sync: creates config with context7 server" {
    export SYNC_TARGETS="codex"
    run sync_ai_run mcp
    [[ "$status" -eq 0 ]]
    [ -f "$CODEX_CONFIG" ]
    grep -q "mcp_servers.context7" "$CODEX_CONFIG"
    grep -q "npx" "$CODEX_CONFIG"
}

@test "mcp_codex_sync: removes stale servers" {
    mkdir -p "$(dirname "$CODEX_CONFIG")"
    printf '[mcp_servers.old-server]\ncommand = "npx old"\nargs = []\n' > "$CODEX_CONFIG"

    export SYNC_TARGETS="codex"
    run sync_ai_run mcp
    [[ "$status" -eq 0 ]]
    ! grep -q "old-server" "$CODEX_CONFIG"
    grep -q "context7" "$CODEX_CONFIG"
}

# =====================================================================
#  Full sync subcommand
# =====================================================================

@test "sync-ai skills: end-to-end creates canonical dir and symlinks" {
    export SYNC_TARGETS="claude,codex"
    run sync_ai_run skills
    [[ "$status" -eq 0 ]]
    [ -d "$AGENTS_SKILLS_DIR" ]
    [ -L "$FAKE_HOME/.claude/skills" ]
    [ -L "$FAKE_HOME/.codex/skills" ]
}
