#!/usr/bin/env bats

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    HOME="$(mktemp -d)"
    export HOME
    TMPDIR="$(mktemp -d)"
    mkdir -p "$HOME/dotfiles"
    cp "$REPO_DIR/globals.sh" "$HOME/dotfiles/globals.sh"
    source "$HOME/dotfiles/globals.sh"
}

teardown() {
    rm -rf "$HOME" "$TMPDIR"
}

@test "globals: exports dotfiles, os and arch" {
    [[ "$DOTFILES_DIR" == "$HOME/dotfiles" ]]
    [[ -n "$OS" ]]
    [[ -n "$ARCH" ]]
    if [[ "$(uname -s)" == "Linux" && -f /etc/os-release ]]; then
        local expected
        expected=$(awk -F= '/^ID=/ {gsub(/"/, "", $2); print tolower($2)}' /etc/os-release)
        [[ "$OS" == "$expected" ]]
    fi
}

@test "cmd_exist: returns expected status" {
    cmd_exist bash
    run cmd_exist "not_a_command_$$"
    [[ "$status" -ne 0 ]]
}

@test "print_color: prints text for known and fallback colors" {
    run print_color green "hello world"
    [[ "$output" == *"hello world"* ]]
    run print_color nonexistent "fallback"
    [[ "$output" == *"fallback"* ]]
}

@test "create_dir: creates nested directories and is idempotent" {
    local d="$TMPDIR/a/b/c"
    create_dir "$d"
    [[ -d "$d" ]]
    run create_dir "$d"
    [[ "$status" -eq 0 ]]
}

@test "load_env_vars: loads, trims, and preserves existing values" {
    local f="$TMPDIR/env-test"
    local original_home="$HOME"
    printf 'TEST_VAR_A=hello42\n  SPACED_KEY  =  spaced_value  \nHOME=/wrong/path\n' >"$f"
    load_env_vars "$f"
    [[ "$TEST_VAR_A" == "hello42" ]]
    [[ "$SPACED_KEY" == "spaced_value" ]]
    [[ "$HOME" == "$original_home" ]]
}

@test "load_env_vars: handles missing file" {
    run load_env_vars "$TMPDIR/nonexistent"
    [[ "$status" -eq 0 ]]
}

@test "add_paths_from_file: adds existing paths once and skips missing paths" {
    local rel="$HOME/test-path-dir"
    local abs="$TMPDIR/abs-path"
    local f="$TMPDIR/paths"
    local old_path="$PATH"
    mkdir -p "$rel" "$abs"
    printf 'test-path-dir\n%s\n/nonexistent/path/xyz42\n' "$abs" >"$f"
    add_paths_from_file "$f"
    [[ ":$PATH:" == *":$rel:"* ]]
    [[ ":$PATH:" == *":$abs:"* ]]
    [[ ":$PATH:" != *":/nonexistent/path/xyz42:"* ]]
    local after_first="$PATH"
    add_paths_from_file "$f"
    [[ "$PATH" == "$after_first" ]]
    export PATH="$old_path"
}

@test "load_env: sources files" {
    local f="$TMPDIR/load-env-test"
    echo "export LOAD_ENV_TEST_VAR=sourced42" >"$f"
    run bash -c "source '$HOME/dotfiles/globals.sh'; load_env '$f'; echo \$LOAD_ENV_TEST_VAR"
    [[ "$output" == *"sourced42"* ]]
}

@test "load_env: reports missing files" {
    run bash -c "source '$HOME/dotfiles/globals.sh'; load_env '$TMPDIR/no-such-file'"
    [[ "$output" == *"does not exist"* ]]
}
