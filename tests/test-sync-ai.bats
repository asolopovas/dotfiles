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

    # Fake bin directory for mock commands
    export FAKE_BIN="$TMPDIR/fake-bin"
    mkdir -p "$FAKE_BIN"

    # Mock git that creates a fake skill directory
    cat > "$FAKE_BIN/git" <<'MOCK'
#!/bin/bash
# Mock git: on "clone" create a fake repo with skill content,
# on "sparse-checkout" do nothing.
case "$1" in
    clone)
        # Find the dest dir (last positional arg)
        dest="${@: -1}"
        mkdir -p "$dest"
        ;;
    -C)
        # sparse-checkout set — create the skill path inside the repo
        repo_dir="$2"
        shift 3  # skip -C <dir> sparse-checkout
        shift    # skip "set"
        subpath="$1"
        mkdir -p "$repo_dir/$subpath"
        cat > "$repo_dir/$subpath/SKILL.md" <<EOF
---
name: $(basename "$subpath")
description: Test skill
---
Test skill content.
EOF
        ;;
esac
exit 0
MOCK
    chmod +x "$FAKE_BIN/git"

    # Mock python3 (needed for require_cmd check)
    printf '#!/bin/sh\nexit 0\n' > "$FAKE_BIN/python3"
    chmod +x "$FAKE_BIN/python3"

    # Mock jq (for MCP sync)
    # Use real jq if available, otherwise create a passthrough
    if command -v jq &>/dev/null; then
        ln -s "$(command -v jq)" "$FAKE_BIN/jq"
    else
        printf '#!/bin/sh\ncat\n' > "$FAKE_BIN/jq"
        chmod +x "$FAKE_BIN/jq"
    fi

    # Mock claude command
    cat > "$FAKE_BIN/claude" <<'MOCK'
#!/bin/bash
case "$1" in
    mcp)
        case "$2" in
            list) echo "" ;;
            get)  exit 1 ;;
            add)  exit 0 ;;
            remove) exit 0 ;;
        esac
        ;;
esac
exit 0
MOCK
    chmod +x "$FAKE_BIN/claude"

    # Set up fake CLI home directories
    mkdir -p "$FAKE_HOME/.claude"
    mkdir -p "$FAKE_HOME/.codex"
    mkdir -p "$FAKE_HOME/.config/opencode"
    mkdir -p "$FAKE_HOME/.agents"

    # Prepend FAKE_BIN to PATH so mocks are found first
    export PATH="$FAKE_BIN:$PATH"

    # Override HOME and related vars
    export HOME="$FAKE_HOME"
    export AGENTS_SKILLS_DIR="$FAKE_HOME/.agents/skills"
    export CODEX_HOME="$FAKE_HOME/.codex"
    export CLAUDE_HOME="$FAKE_HOME/.claude"
    export OPENCODE_HOME="$FAKE_HOME/.config/opencode"
    export DOTFILES_DIR="$REPO_DIR"
    export CODEX_CONFIG="$FAKE_HOME/.codex/config.toml"

    # Prevent agents sync from trying to read agents.conf
    export AGENTS_CONFIG="$TMPDIR/empty-agents.conf"
    touch "$AGENTS_CONFIG"
}

teardown() {
    rm -rf "$FAKE_HOME" "$TMPDIR"
}

# Helper: source sync-ai.sh functions without running main()
load_sync_ai() {
    # Source the script but override main() to prevent execution
    source <(sed 's/^main "\$@"$//' "$REPO_DIR/scripts/sync-ai.sh")
}

# Helper: run sync-ai.sh with args
sync_ai_run() {
    env HOME="$FAKE_HOME" \
        AGENTS_SKILLS_DIR="$AGENTS_SKILLS_DIR" \
        CODEX_HOME="$CODEX_HOME" \
        CLAUDE_HOME="$CLAUDE_HOME" \
        OPENCODE_HOME="$OPENCODE_HOME" \
        DOTFILES_DIR="$REPO_DIR" \
        CODEX_CONFIG="$CODEX_CONFIG" \
        AGENTS_CONFIG="$AGENTS_CONFIG" \
        PATH="$FAKE_BIN:$PATH" \
        bash "$REPO_DIR/scripts/sync-ai.sh" "$@"
}

# =====================================================================
#  ensure_skill_symlink
# =====================================================================

@test "ensure_skill_symlink: creates symlink to agents skills dir" {
    load_sync_ai
    mkdir -p "$AGENTS_SKILLS_DIR"

    ensure_skill_symlink "$FAKE_HOME/.claude/skills"

    [ -L "$FAKE_HOME/.claude/skills" ]
    local target
    target=$(readlink "$FAKE_HOME/.claude/skills")
    [[ "$target" == "$AGENTS_SKILLS_DIR" ]]
}

@test "ensure_skill_symlink: replaces existing directory with symlink" {
    load_sync_ai
    mkdir -p "$AGENTS_SKILLS_DIR"

    # Create a real directory with content
    mkdir -p "$FAKE_HOME/.codex/skills/old-skill"
    touch "$FAKE_HOME/.codex/skills/old-skill/SKILL.md"

    ensure_skill_symlink "$FAKE_HOME/.codex/skills"

    [ -L "$FAKE_HOME/.codex/skills" ]
    local target
    target=$(readlink "$FAKE_HOME/.codex/skills")
    [[ "$target" == "$AGENTS_SKILLS_DIR" ]]
}

@test "ensure_skill_symlink: replaces wrong symlink target" {
    load_sync_ai
    mkdir -p "$AGENTS_SKILLS_DIR"

    # Create a symlink pointing elsewhere
    ln -s /wrong/target "$FAKE_HOME/.claude/skills"

    ensure_skill_symlink "$FAKE_HOME/.claude/skills"

    [ -L "$FAKE_HOME/.claude/skills" ]
    local target
    target=$(readlink "$FAKE_HOME/.claude/skills")
    [[ "$target" == "$AGENTS_SKILLS_DIR" ]]
}

@test "ensure_skill_symlink: idempotent when already correct" {
    load_sync_ai
    mkdir -p "$AGENTS_SKILLS_DIR"

    # Create correct symlink
    ln -s "$AGENTS_SKILLS_DIR" "$FAKE_HOME/.claude/skills"

    run ensure_skill_symlink "$FAKE_HOME/.claude/skills"
    [[ "$status" -eq 0 ]]

    [ -L "$FAKE_HOME/.claude/skills" ]
    local target
    target=$(readlink "$FAKE_HOME/.claude/skills")
    [[ "$target" == "$AGENTS_SKILLS_DIR" ]]
}

@test "ensure_skill_symlink: creates parent directories" {
    load_sync_ai
    mkdir -p "$AGENTS_SKILLS_DIR"

    # Remove .codex dir entirely
    rm -rf "$FAKE_HOME/.codex"

    ensure_skill_symlink "$FAKE_HOME/.codex/skills"

    [ -L "$FAKE_HOME/.codex/skills" ]
}

# =====================================================================
#  sync_skills — skill installation to canonical dir
# =====================================================================

@test "sync_skills: installs skills to ~/.agents/skills" {
    load_sync_ai
    TARGETS=(claude)
    resolve_targets 2>/dev/null || TARGETS=(claude)

    sync_skills

    # Should have created the canonical dir
    [ -d "$AGENTS_SKILLS_DIR" ]
}

@test "sync_skills: creates claude symlink" {
    load_sync_ai
    TARGETS=(claude)

    sync_skills

    [ -L "$FAKE_HOME/.claude/skills" ]
    local target
    target=$(readlink "$FAKE_HOME/.claude/skills")
    [[ "$target" == "$AGENTS_SKILLS_DIR" ]]
}

@test "sync_skills: creates codex symlink when codex is a target" {
    load_sync_ai
    TARGETS=(codex)

    sync_skills

    [ -L "$FAKE_HOME/.codex/skills" ]
    local target
    target=$(readlink "$FAKE_HOME/.codex/skills")
    [[ "$target" == "$AGENTS_SKILLS_DIR" ]]
}

@test "sync_skills: does NOT create opencode symlink (reads natively)" {
    load_sync_ai
    TARGETS=(opencode)

    # Pre-existing opencode skills dir
    mkdir -p "$FAKE_HOME/.config/opencode/skills"

    sync_skills

    # opencode skills should NOT become a symlink
    [ ! -L "$FAKE_HOME/.config/opencode/skills" ]
}

@test "sync_skills: removes skills not in desired set" {
    load_sync_ai
    TARGETS=(claude)

    # Pre-install an unwanted skill in canonical dir
    mkdir -p "$AGENTS_SKILLS_DIR/unwanted-skill"
    cat > "$AGENTS_SKILLS_DIR/unwanted-skill/SKILL.md" <<EOF
---
name: unwanted-skill
description: Should be removed
---
EOF

    sync_skills

    [ ! -d "$AGENTS_SKILLS_DIR/unwanted-skill" ]
}

@test "sync_skills: preserves dotfiles in skills dir" {
    load_sync_ai
    TARGETS=(claude)

    # .system dir should be preserved (starts with dot)
    mkdir -p "$AGENTS_SKILLS_DIR/.system/skill-installer"
    touch "$AGENTS_SKILLS_DIR/.system/skill-installer/test"

    sync_skills

    [ -d "$AGENTS_SKILLS_DIR/.system" ]
}

# =====================================================================
#  Skills visible through symlinks
# =====================================================================

@test "symlinks: claude sees skills from canonical dir" {
    load_sync_ai
    mkdir -p "$AGENTS_SKILLS_DIR/test-skill"
    cat > "$AGENTS_SKILLS_DIR/test-skill/SKILL.md" <<EOF
---
name: test-skill
description: Test
---
EOF

    ensure_skill_symlink "$FAKE_HOME/.claude/skills"

    # Claude should see the skill through the symlink
    [ -f "$FAKE_HOME/.claude/skills/test-skill/SKILL.md" ]
}

@test "symlinks: codex sees skills from canonical dir" {
    load_sync_ai
    mkdir -p "$AGENTS_SKILLS_DIR/test-skill"
    cat > "$AGENTS_SKILLS_DIR/test-skill/SKILL.md" <<EOF
---
name: test-skill
description: Test
---
EOF

    ensure_skill_symlink "$FAKE_HOME/.codex/skills"

    [ -f "$FAKE_HOME/.codex/skills/test-skill/SKILL.md" ]
}

@test "symlinks: all CLIs see same skill content" {
    load_sync_ai

    # Create skill in canonical dir
    mkdir -p "$AGENTS_SKILLS_DIR/shared-skill"
    echo "shared content" > "$AGENTS_SKILLS_DIR/shared-skill/SKILL.md"

    # Set up symlinks
    ensure_skill_symlink "$FAKE_HOME/.claude/skills"
    ensure_skill_symlink "$FAKE_HOME/.codex/skills"

    # All three paths should resolve to same content
    local claude_content codex_content agents_content
    agents_content=$(cat "$AGENTS_SKILLS_DIR/shared-skill/SKILL.md")
    claude_content=$(cat "$FAKE_HOME/.claude/skills/shared-skill/SKILL.md")
    codex_content=$(cat "$FAKE_HOME/.codex/skills/shared-skill/SKILL.md")

    [[ "$agents_content" == "$claude_content" ]]
    [[ "$agents_content" == "$codex_content" ]]
}

# =====================================================================
#  Target resolution
# =====================================================================

@test "resolve_targets: detects claude when dir exists" {
    load_sync_ai
    TARGETS=()

    export SYNC_TARGETS="claude"
    resolve_targets

    [[ " ${TARGETS[*]} " == *" claude "* ]]
}

@test "resolve_targets: detects codex when dir exists" {
    load_sync_ai
    TARGETS=()

    export SYNC_TARGETS="codex"
    resolve_targets

    [[ " ${TARGETS[*]} " == *" codex "* ]]
}

@test "resolve_targets: detects opencode when dir exists" {
    load_sync_ai
    TARGETS=()

    export SYNC_TARGETS="opencode"
    resolve_targets

    [[ " ${TARGETS[*]} " == *" opencode "* ]]
}

@test "resolve_targets: skips unknown targets" {
    load_sync_ai
    TARGETS=()

    export SYNC_TARGETS="claude,bogus"
    run resolve_targets

    # Should warn about bogus
    [[ "$output" == *"unknown"* ]] || [[ "$output" == *"Warning"* ]]
}

# =====================================================================
#  cli_home
# =====================================================================

@test "cli_home: returns correct paths" {
    load_sync_ai

    local claude_home codex_home opencode_home
    claude_home=$(cli_home claude)
    codex_home=$(cli_home codex)
    opencode_home=$(cli_home opencode)

    [[ "$claude_home" == "$FAKE_HOME/.claude" ]]
    [[ "$codex_home" == "$FAKE_HOME/.codex" ]]
    [[ "$opencode_home" == "$FAKE_HOME/.config/opencode" ]]
}

@test "cli_home: fails for unknown CLI" {
    load_sync_ai

    run cli_home notreal
    [[ "$status" -ne 0 ]]
}

# =====================================================================
#  skill_name_from_url
# =====================================================================

@test "skill_name_from_url: extracts name from GitHub tree URL" {
    load_sync_ai

    local name
    name=$(skill_name_from_url "https://github.com/owner/repo/tree/main/skills/my-skill")
    [[ "$name" == "my-skill" ]]
}

@test "skill_name_from_url: handles nested paths" {
    load_sync_ai

    local name
    name=$(skill_name_from_url "https://github.com/davila7/claude-code-templates/tree/main/cli-tool/components/skills/development/error-resolver")
    [[ "$name" == "error-resolver" ]]
}

@test "skill_name_from_url: strips trailing SKILL.md" {
    load_sync_ai

    local name
    name=$(skill_name_from_url "https://github.com/owner/repo/tree/main/skills/my-skill/SKILL.md")
    [[ "$name" == "my-skill" ]]
}

# =====================================================================
#  normalize_skill_source
# =====================================================================

@test "normalize_skill_source: strips query params and SKILL.md" {
    load_sync_ai

    local src
    src=$(normalize_skill_source "https://github.com/owner/repo/tree/main/skills/test?tab=readme#section")
    [[ "$src" == "https://github.com/owner/repo/tree/main/skills/test" ]]
}

@test "normalize_skill_source: respects SKILLS_REF override" {
    load_sync_ai
    export SKILLS_REF="v2.0"

    local src
    src=$(normalize_skill_source "https://github.com/owner/repo/tree/main/skills/test")
    [[ "$src" == "https://github.com/owner/repo/tree/v2.0/skills/test" ]]
}

# =====================================================================
#  AGENTS_SKILLS_DIR variable
# =====================================================================

@test "config: AGENTS_SKILLS_DIR defaults to ~/.agents/skills" {
    # Source with a clean AGENTS_SKILLS_DIR
    unset AGENTS_SKILLS_DIR
    export HOME="$FAKE_HOME"
    source <(sed 's/^main "\$@"$//' "$REPO_DIR/scripts/sync-ai.sh")

    [[ "$AGENTS_SKILLS_DIR" == "$FAKE_HOME/.agents/skills" ]]
}

@test "config: AGENTS_SKILLS_DIR respects env override" {
    export AGENTS_SKILLS_DIR="/custom/skills/path"
    source <(sed 's/^main "\$@"$//' "$REPO_DIR/scripts/sync-ai.sh")

    [[ "$AGENTS_SKILLS_DIR" == "/custom/skills/path" ]]
}

# =====================================================================
#  resolve_skill_installer
# =====================================================================

@test "resolve_skill_installer: finds installer in agents skills dir" {
    load_sync_ai

    # Create fake installer
    mkdir -p "$AGENTS_SKILLS_DIR/.system/skill-installer/scripts"
    touch "$AGENTS_SKILLS_DIR/.system/skill-installer/scripts/install-skill-from-github.py"

    local result
    result=$(resolve_skill_installer)
    [[ "$result" == *".agents/skills/.system/skill-installer/scripts/install-skill-from-github.py" ]]
}

@test "resolve_skill_installer: respects SKILL_INSTALLER env var" {
    load_sync_ai

    local fake_installer="$TMPDIR/my-installer.py"
    touch "$fake_installer"
    export SKILL_INSTALLER="$fake_installer"

    local result
    result=$(resolve_skill_installer)
    [[ "$result" == "$fake_installer" ]]
}

# =====================================================================
#  MCP: codex config.toml sync
# =====================================================================

@test "mcp_codex_sync: creates config.toml with server entries" {
    # Run mcp sync via the script directly to avoid declare -A issues in bats
    export SYNC_TARGETS="codex"
    run sync_ai_run mcp

    [[ "$status" -eq 0 ]]
    [ -f "$CODEX_CONFIG" ]
    # Should contain the context7 server
    grep -q "mcp_servers.context7" "$CODEX_CONFIG"
    grep -q "npx" "$CODEX_CONFIG"
}

@test "mcp_codex_sync: removes servers not in MCP_SERVERS" {
    # Pre-create config with an extra server
    mkdir -p "$(dirname "$CODEX_CONFIG")"
    cat > "$CODEX_CONFIG" <<EOF
[mcp_servers.old-server]
command = "npx old-server"
args = []
EOF

    export SYNC_TARGETS="codex"
    run sync_ai_run mcp

    [[ "$status" -eq 0 ]]
    # old-server should be gone
    ! grep -q "old-server" "$CODEX_CONFIG"
    # context7 should be present
    grep -q "context7" "$CODEX_CONFIG"
}

# =====================================================================
#  Full sync (skills subcommand)
# =====================================================================

@test "sync-ai skills: creates canonical dir and symlinks" {
    export SYNC_TARGETS="claude,codex"
    run sync_ai_run skills

    [[ "$status" -eq 0 ]]
    [ -d "$AGENTS_SKILLS_DIR" ]
    [ -L "$FAKE_HOME/.claude/skills" ]
    [ -L "$FAKE_HOME/.codex/skills" ]
}
