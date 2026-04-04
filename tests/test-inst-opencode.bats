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
    export FAKE_BIN="$TMPDIR/fake-bin"
    mkdir -p "$FAKE_BIN"

    # Mock opencode (already installed), curl (no-op), bunx (must not be called)
    printf '#!/bin/sh\necho "0.0.0-test"\n' > "$FAKE_BIN/opencode" && chmod +x "$FAKE_BIN/opencode"
    printf '#!/bin/sh\nexit 0\n'             > "$FAKE_BIN/curl"     && chmod +x "$FAKE_BIN/curl"
    printf '#!/bin/sh\necho "FAIL: bunx called" >&2; exit 1\n' \
                                              > "$FAKE_BIN/bunx"    && chmod +x "$FAKE_BIN/bunx"

    # Dotfiles source config
    mkdir -p "$FAKE_HOME/dotfiles/.config/opencode/agents"
    echo '{"key": "val"}'  > "$FAKE_HOME/dotfiles/.config/opencode/config.json"
    echo '// test jsonc'   > "$FAKE_HOME/dotfiles/.config/opencode/opencode.jsonc"
    echo '# agent'         > "$FAKE_HOME/dotfiles/.config/opencode/agents/test-agent.md"

    # Minimal globals.sh stub
    cat > "$FAKE_HOME/dotfiles/globals.sh" <<'G'
cmd_exist() { command -v "$1" &>/dev/null; }
print_color() { shift; echo "$*"; }
G

    export PATH="$FAKE_BIN:$PATH"
    export HOME="$FAKE_HOME"
    export DOTFILES_DIR="$FAKE_HOME/dotfiles"
}

teardown() {
    rm -rf "$FAKE_HOME" "$TMPDIR"
}

opencode_run() {
    bash "$REPO_DIR/scripts/inst-opencode.sh"
}

assert_opencode_symlink() {
    local dst="$FAKE_HOME/.config/opencode/$1"
    [ -L "$dst" ]
    [[ "$(readlink "$dst")" == "$FAKE_HOME/dotfiles/.config/opencode/$1" ]]
}

# =====================================================================
#  Config symlinks
# =====================================================================

@test "opencode: symlinks all config items to dotfiles" {
    opencode_run
    for item in config.json opencode.jsonc agents; do
        assert_opencode_symlink "$item"
    done
}

@test "opencode: idempotent (second run succeeds)" {
    opencode_run
    run opencode_run
    [[ "$status" -eq 0 ]]
}

@test "opencode: replaces existing file with symlink" {
    mkdir -p "$FAKE_HOME/.config/opencode"
    echo "old" > "$FAKE_HOME/.config/opencode/config.json"
    opencode_run
    [ -L "$FAKE_HOME/.config/opencode/config.json" ]
}

@test "opencode: replaces wrong symlink target" {
    mkdir -p "$FAKE_HOME/.config/opencode"
    ln -s /wrong/path "$FAKE_HOME/.config/opencode/config.json"
    opencode_run
    assert_opencode_symlink "config.json"
}

@test "opencode: creates destination dir if missing" {
    rm -rf "$FAKE_HOME/.config/opencode"
    opencode_run
    [ -d "$FAKE_HOME/.config/opencode" ]
}

# =====================================================================
#  Skills NOT installed (moved to sync-ai.sh)
# =====================================================================

@test "opencode: does not install skills or call bunx" {
    run opencode_run
    [[ "$status" -eq 0 ]]
    [ ! -d "$FAKE_HOME/.config/opencode/skills" ]
    [[ "$output" != *"Installing OpenCode skills"* ]]
}

@test "opencode: output mentions sync-ai.sh" {
    run opencode_run
    [[ "$output" == *"sync-ai.sh"* ]]
}

# =====================================================================
#  Binary detection
# =====================================================================

@test "opencode: skips install when already present" {
    run opencode_run
    [[ "$output" == *"already installed"* ]]
}

@test "opencode: attempts install when not present" {
    rm -f "$FAKE_BIN/opencode"

    # Build PATH excluding dirs with real opencode
    local filtered="" IFS=':'
    for dir in $PATH; do
        [[ -x "$dir/opencode" ]] || filtered="${filtered:+$filtered:}$dir"
    done

    run env PATH="$FAKE_BIN:$filtered" bash "$REPO_DIR/scripts/inst-opencode.sh"
    [[ "$output" == *"Installing OpenCode"* ]]
}
