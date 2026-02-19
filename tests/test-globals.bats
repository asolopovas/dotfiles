#!/usr/bin/env bats

# ---------------------------------------------------------------------------
# Unit tests for globals.sh — core shared library.
# Runs locally, no Docker, no network, no sudo.
# ---------------------------------------------------------------------------

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    export HOME="$(mktemp -d)"
    mkdir -p "$HOME/dotfiles"
    cp "$REPO_DIR/globals.sh" "$HOME/dotfiles/globals.sh"
    # Provide a minimal /etc/os-release parse
    source "$HOME/dotfiles/globals.sh"
    TMPDIR="$(mktemp -d)"
}

teardown() {
    rm -rf "$HOME" "$TMPDIR"
}

# ---- DOTFILES_DIR ----

@test "globals: exports DOTFILES_DIR" {
    [[ "$DOTFILES_DIR" == "$HOME/dotfiles" ]]
}

# ---- OS detection ----

@test "globals: exports OS (non-empty)" {
    [[ -n "$OS" ]]
}

@test "globals: OS matches /etc/os-release" {
    local expected
    expected=$(awk -F= '/^ID=/ {gsub(/"/, "", $2); print tolower($2)}' /etc/os-release)
    [[ "$OS" == "$expected" ]]
}

# ---- cmd_exist ----

@test "cmd_exist: finds bash" {
    cmd_exist bash
}

@test "cmd_exist: finds ls" {
    cmd_exist ls
}

@test "cmd_exist: rejects nonexistent command" {
    run cmd_exist no_such_command_42xyz
    [[ "$status" -ne 0 ]]
}

@test "cmd_exist: rejects random string" {
    run cmd_exist "not_a_command_$$"
    [[ "$status" -ne 0 ]]
}

# ---- print_color ----

@test "print_color: outputs text with green" {
    run print_color green "hello world"
    [[ "$output" == *"hello world"* ]]
}

@test "print_color: outputs text with red" {
    run print_color red "error msg"
    [[ "$output" == *"error msg"* ]]
}

@test "print_color: unknown color still outputs text" {
    run print_color nonexistent "fallback"
    [[ "$output" == *"fallback"* ]]
}

@test "print_color: bold variants work" {
    run print_color bold_blue "bold test"
    [[ "$output" == *"bold test"* ]]
}

# ---- create_dir ----

@test "create_dir: creates new directory" {
    local d="$TMPDIR/new-dir"
    create_dir "$d"
    [[ -d "$d" ]]
}

@test "create_dir: creates nested directories" {
    local d="$TMPDIR/a/b/c"
    create_dir "$d"
    [[ -d "$d" ]]
}

@test "create_dir: idempotent on existing dir" {
    local d="$TMPDIR/existing"
    mkdir -p "$d"
    run create_dir "$d"
    [[ "$status" -eq 0 ]]
    [[ -d "$d" ]]
}

# ---- load_env_vars ----

@test "load_env_vars: loads KEY=VALUE pairs" {
    local f="$TMPDIR/env-test"
    echo "TEST_VAR_A=hello42" > "$f"
    load_env_vars "$f"
    [[ "$TEST_VAR_A" == "hello42" ]]
}

@test "load_env_vars: loads multiple vars" {
    local f="$TMPDIR/env-multi"
    printf 'VAR_ONE=alpha\nVAR_TWO=beta\n' > "$f"
    load_env_vars "$f"
    [[ "$VAR_ONE" == "alpha" ]]
    [[ "$VAR_TWO" == "beta" ]]
}

@test "load_env_vars: skips already-set variables" {
    local f="$TMPDIR/env-skip"
    echo "HOME=/wrong/path" > "$f"
    local original_home="$HOME"
    load_env_vars "$f"
    [[ "$HOME" == "$original_home" ]]
}

@test "load_env_vars: handles missing file gracefully" {
    run load_env_vars "$TMPDIR/nonexistent"
    [[ "$status" -eq 0 ]]
}

@test "load_env_vars: handles whitespace in values" {
    local f="$TMPDIR/env-ws"
    echo "  SPACED_KEY  =  spaced_value  " > "$f"
    load_env_vars "$f"
    [[ "$SPACED_KEY" == "spaced_value" ]]
}

# ---- add_paths_from_file ----

@test "add_paths_from_file: adds relative paths as HOME-prefixed" {
    local f="$TMPDIR/paths"
    local testdir="$HOME/test-path-dir"
    mkdir -p "$testdir"
    echo "test-path-dir" > "$f"
    local old_path="$PATH"
    add_paths_from_file "$f"
    [[ ":$PATH:" == *":$testdir:"* ]]
    export PATH="$old_path"
}

@test "add_paths_from_file: adds absolute paths directly" {
    local testdir="$TMPDIR/abs-path"
    mkdir -p "$testdir"
    local f="$TMPDIR/abs-paths"
    echo "$testdir" > "$f"
    local old_path="$PATH"
    add_paths_from_file "$f"
    [[ ":$PATH:" == *":$testdir:"* ]]
    export PATH="$old_path"
}

@test "add_paths_from_file: skips nonexistent directories" {
    local f="$TMPDIR/missing-paths"
    echo "/nonexistent/path/xyz42" > "$f"
    local old_path="$PATH"
    add_paths_from_file "$f"
    [[ ":$PATH:" != *":/nonexistent/path/xyz42:"* ]]
    export PATH="$old_path"
}

@test "add_paths_from_file: no duplicates on second call" {
    local testdir="$TMPDIR/dup-test"
    mkdir -p "$testdir"
    local f="$TMPDIR/dup-paths"
    echo "$testdir" > "$f"
    local old_path="$PATH"
    add_paths_from_file "$f"
    local after_first="$PATH"
    add_paths_from_file "$f"
    [[ "$PATH" == "$after_first" ]]
    export PATH="$old_path"
}

# ---- load_env ----

@test "load_env: sources a file" {
    local f="$TMPDIR/load-env-test"
    echo "export LOAD_ENV_TEST_VAR=sourced42" > "$f"
    # load_env uses set -e, so we run in subshell
    run bash -c "source '$HOME/dotfiles/globals.sh'; load_env '$f'; echo \$LOAD_ENV_TEST_VAR"
    [[ "$output" == *"sourced42"* ]]
}

@test "load_env: handles missing file" {
    run bash -c "source '$HOME/dotfiles/globals.sh'; load_env '$TMPDIR/no-such-file'"
    [[ "$output" == *"does not exist"* ]]
}
