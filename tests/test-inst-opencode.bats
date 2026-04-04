#!/usr/bin/env bats

# ---------------------------------------------------------------------------
# Unit tests for inst-opencode.sh — OpenCode binary install + config setup.
# Verifies skills are NOT installed (moved to sync-ai.sh).
# Runs locally, no Docker, no network, no sudo.
# ---------------------------------------------------------------------------

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    export FAKE_HOME="$(mktemp -d)"
    export TMPDIR="$(mktemp -d)"

    # Fake bin directory for mock commands
    export FAKE_BIN="$TMPDIR/fake-bin"
    mkdir -p "$FAKE_BIN"

    # Mock opencode as already installed
    cat > "$FAKE_BIN/opencode" <<'MOCK'
#!/bin/bash
echo "0.0.0-test"
MOCK
    chmod +x "$FAKE_BIN/opencode"

    # Mock curl (should NOT be called for skills)
    cat > "$FAKE_BIN/curl" <<'MOCK'
#!/bin/bash
echo "curl mock called with: $*" >&2
exit 0
MOCK
    chmod +x "$FAKE_BIN/curl"

    # Mock bunx — should NOT be called (skills removed)
    cat > "$FAKE_BIN/bunx" <<'MOCK'
#!/bin/bash
echo "FAIL: bunx should not be called" >&2
exit 1
MOCK
    chmod +x "$FAKE_BIN/bunx"

    # Create dotfiles source config
    mkdir -p "$FAKE_HOME/dotfiles/.config/opencode/agents"
    echo '{"key": "val"}' > "$FAKE_HOME/dotfiles/.config/opencode/config.json"
    echo '// test jsonc' > "$FAKE_HOME/dotfiles/.config/opencode/opencode.jsonc"
    echo '# agent' > "$FAKE_HOME/dotfiles/.config/opencode/agents/test-agent.md"

    # Create a fake globals.sh
    cat > "$FAKE_HOME/dotfiles/globals.sh" <<'GLOBALS'
cmd_exist() { command -v "$1" &>/dev/null; }
print_color() { shift; echo "$*"; }
GLOBALS

    export PATH="$FAKE_BIN:$PATH"
    export HOME="$FAKE_HOME"
    export DOTFILES_DIR="$FAKE_HOME/dotfiles"
}

teardown() {
    rm -rf "$FAKE_HOME" "$TMPDIR"
}

# Helper to run inst-opencode.sh
opencode_run() {
    env HOME="$FAKE_HOME" \
        DOTFILES_DIR="$FAKE_HOME/dotfiles" \
        PATH="$FAKE_BIN:$PATH" \
        bash "$REPO_DIR/scripts/inst-opencode.sh"
}

# =====================================================================
#  Config symlinks (Linux)
# =====================================================================

@test "opencode: creates config.json symlink" {
    opencode_run

    [ -L "$FAKE_HOME/.config/opencode/config.json" ]
    local target
    target=$(readlink "$FAKE_HOME/.config/opencode/config.json")
    [[ "$target" == "$FAKE_HOME/dotfiles/.config/opencode/config.json" ]]
}

@test "opencode: creates opencode.jsonc symlink" {
    opencode_run

    [ -L "$FAKE_HOME/.config/opencode/opencode.jsonc" ]
    local target
    target=$(readlink "$FAKE_HOME/.config/opencode/opencode.jsonc")
    [[ "$target" == "$FAKE_HOME/dotfiles/.config/opencode/opencode.jsonc" ]]
}

@test "opencode: creates agents dir symlink" {
    opencode_run

    [ -L "$FAKE_HOME/.config/opencode/agents" ]
    local target
    target=$(readlink "$FAKE_HOME/.config/opencode/agents")
    [[ "$target" == "$FAKE_HOME/dotfiles/.config/opencode/agents" ]]
}

@test "opencode: symlink targets are correct dotfiles paths" {
    opencode_run

    for item in config.json opencode.jsonc agents; do
        local target
        target=$(readlink "$FAKE_HOME/.config/opencode/$item")
        [[ "$target" == "$FAKE_HOME/dotfiles/.config/opencode/$item" ]]
    done
}

@test "opencode: idempotent (second run succeeds)" {
    opencode_run
    run opencode_run
    [[ "$status" -eq 0 ]]
}

@test "opencode: replaces existing file with symlink" {
    mkdir -p "$FAKE_HOME/.config/opencode"
    echo "old content" > "$FAKE_HOME/.config/opencode/config.json"

    opencode_run

    [ -L "$FAKE_HOME/.config/opencode/config.json" ]
}

@test "opencode: replaces wrong symlink target" {
    mkdir -p "$FAKE_HOME/.config/opencode"
    ln -s /wrong/path "$FAKE_HOME/.config/opencode/config.json"

    opencode_run

    local target
    target=$(readlink "$FAKE_HOME/.config/opencode/config.json")
    [[ "$target" == "$FAKE_HOME/dotfiles/.config/opencode/config.json" ]]
}

# =====================================================================
#  Skills NOT installed
# =====================================================================

@test "opencode: does NOT install skills" {
    opencode_run

    # No skills directory should be created by inst-opencode.sh
    [ ! -d "$FAKE_HOME/.config/opencode/skills" ]
}

@test "opencode: does NOT call bunx" {
    # bunx mock exits with failure — if it were called, the run would fail
    run opencode_run
    [[ "$status" -eq 0 ]]

    # Double-check output doesn't mention skills install
    [[ "$output" != *"Installing OpenCode skills"* ]]
}

@test "opencode: output mentions sync-ai.sh for skills" {
    run opencode_run
    [[ "$output" == *"sync-ai.sh"* ]]
}

# =====================================================================
#  OpenCode binary detection
# =====================================================================

@test "opencode: skips install when already present" {
    run opencode_run
    [[ "$output" == *"already installed"* ]]
}

@test "opencode: attempts install when not present" {
    rm -f "$FAKE_BIN/opencode"

    # Build a PATH that excludes dirs containing the real opencode binary
    # but keeps system essentials (/usr/bin, /bin, etc.)
    local filtered_path=""
    local IFS=':'
    for dir in $PATH; do
        [[ -x "$dir/opencode" ]] && continue
        filtered_path="${filtered_path:+$filtered_path:}$dir"
    done

    run env HOME="$FAKE_HOME" \
        DOTFILES_DIR="$FAKE_HOME/dotfiles" \
        PATH="$FAKE_BIN:$filtered_path" \
        bash "$REPO_DIR/scripts/inst-opencode.sh"

    # Should attempt to install (curl mock will be called)
    [[ "$output" == *"Installing OpenCode"* ]]
}

# =====================================================================
#  Destination directory creation
# =====================================================================

@test "opencode: creates destination dir if missing" {
    # Remove the default config dir
    rm -rf "$FAKE_HOME/.config/opencode"

    opencode_run

    [ -d "$FAKE_HOME/.config/opencode" ]
}
