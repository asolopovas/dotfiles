#!/usr/bin/env bats

# ---------------------------------------------------------------------------
# Unit tests for core scripts — runs locally, no Docker, no network.
# Tests: ops-update-symlinks.sh, cfg-dev-tools-proxy.sh --remove,
#        env/include-paths.sh, helpers/ls-path, .profile sourcability.
# ---------------------------------------------------------------------------

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    export FAKE_HOME="$(mktemp -d)"
    export TMPDIR="$(mktemp -d)"

    # Fake sudo that just runs the command without privilege escalation.
    # Prevents tests from triggering real sudo/pin prompts.
    export FAKE_BIN="$TMPDIR/fake-bin"
    mkdir -p "$FAKE_BIN"
    printf '#!/bin/sh\n# skip -n flag check\nwhile [ $# -gt 0 ]; do case "$1" in -n|-E) shift;; -*) shift;; *) break;; esac; done\n"$@"\n' \
        > "$FAKE_BIN/sudo"
    chmod +x "$FAKE_BIN/sudo"

    # Create a minimal dotfiles clone for scripts that expect it
    mkdir -p "$FAKE_HOME/dotfiles/.config/fish"
    mkdir -p "$FAKE_HOME/dotfiles/.config/nvim"
    mkdir -p "$FAKE_HOME/dotfiles/.config/tmux"
    mkdir -p "$FAKE_HOME/dotfiles/.config/claude/commands"
    touch "$FAKE_HOME/dotfiles/.config/.aliasrc"
    touch "$FAKE_HOME/dotfiles/.config/.func"
    echo '{"key": "val"}' > "$FAKE_HOME/dotfiles/.config/claude/settings.json"
}

teardown() {
    rm -rf "$FAKE_HOME" "$TMPDIR"
}

# =====================================================================
#  ops-update-symlinks.sh
# =====================================================================

@test "symlinks: creates all expected symlinks" {
    local real_home="$FAKE_HOME"
    HOME="$real_home" DOTFILES_DIR="$real_home/dotfiles" \
        bash "$REPO_DIR/scripts/ops-update-symlinks.sh"

    [ -L "$real_home/.config/fish" ]
    [ -L "$real_home/.config/nvim" ]
    [ -L "$real_home/.config/tmux" ]
    [ -L "$real_home/.config/.aliasrc" ]
    [ -L "$real_home/.config/.func" ]
    [ -L "$real_home/.claude/settings.json" ]
    [ -L "$real_home/.claude/commands" ]
}

@test "symlinks: targets point to dotfiles repo" {
    HOME="$FAKE_HOME" DOTFILES_DIR="$FAKE_HOME/dotfiles" \
        bash "$REPO_DIR/scripts/ops-update-symlinks.sh"

    local target
    target=$(readlink "$FAKE_HOME/.config/nvim")
    [[ "$target" == "$FAKE_HOME/dotfiles/.config/nvim" ]]
}

@test "symlinks: idempotent (second run succeeds)" {
    HOME="$FAKE_HOME" DOTFILES_DIR="$FAKE_HOME/dotfiles" \
        bash "$REPO_DIR/scripts/ops-update-symlinks.sh"
    run bash -c "HOME='$FAKE_HOME' DOTFILES_DIR='$FAKE_HOME/dotfiles' bash '$REPO_DIR/scripts/ops-update-symlinks.sh'"
    [[ "$status" -eq 0 ]]
}

@test "symlinks: replaces existing symlink with updated target" {
    mkdir -p "$FAKE_HOME/.config"
    ln -s /old/target "$FAKE_HOME/.config/nvim"

    HOME="$FAKE_HOME" DOTFILES_DIR="$FAKE_HOME/dotfiles" \
        bash "$REPO_DIR/scripts/ops-update-symlinks.sh"

    local target
    target=$(readlink "$FAKE_HOME/.config/nvim")
    [[ "$target" == "$FAKE_HOME/dotfiles/.config/nvim" ]]
}

@test "symlinks: rejects XDG_CONFIG_HOME inside repo" {
    run bash -c "HOME='$FAKE_HOME' DOTFILES_DIR='$FAKE_HOME/dotfiles' XDG_CONFIG_HOME='$FAKE_HOME/dotfiles/.config' bash '$REPO_DIR/scripts/ops-update-symlinks.sh'"
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"Refusing"* ]]
}

@test "symlinks: respects custom XDG_CONFIG_HOME" {
    local custom_xdg="$TMPDIR/custom-config"
    mkdir -p "$custom_xdg"

    HOME="$FAKE_HOME" DOTFILES_DIR="$FAKE_HOME/dotfiles" XDG_CONFIG_HOME="$custom_xdg" \
        bash "$REPO_DIR/scripts/ops-update-symlinks.sh"

    [ -L "$custom_xdg/fish" ]
    [ -L "$custom_xdg/nvim" ]
    [ -L "$custom_xdg/tmux" ]
}

# =====================================================================
#  cfg-dev-tools-proxy.sh --remove
# =====================================================================

@test "proxy-remove: cleans wgetrc and curlrc" {
    mkdir -p "$TMPDIR/proxy-home/.pip" "$TMPDIR/proxy-home/.config/pip"
    echo "proxy" > "$TMPDIR/proxy-home/.wgetrc"
    echo "proxy" > "$TMPDIR/proxy-home/.curlrc"
    echo "proxy" > "$TMPDIR/proxy-home/.pip/pip.conf"
    echo "proxy" > "$TMPDIR/proxy-home/.config/pip/pip.conf"

    run env HOME="$TMPDIR/proxy-home" PATH="$FAKE_BIN:$PATH" bash "$REPO_DIR/scripts/cfg-dev-tools-proxy.sh" --remove
    [[ "$status" -eq 0 ]]
    [ ! -f "$TMPDIR/proxy-home/.wgetrc" ]
    [ ! -f "$TMPDIR/proxy-home/.curlrc" ]
    [ ! -f "$TMPDIR/proxy-home/.pip/pip.conf" ]
    [ ! -f "$TMPDIR/proxy-home/.config/pip/pip.conf" ]
}

@test "proxy-remove: idempotent (no files to remove)" {
    local empty_home="$TMPDIR/empty-home"
    mkdir -p "$empty_home"
    run env HOME="$empty_home" PATH="$FAKE_BIN:$PATH" bash "$REPO_DIR/scripts/cfg-dev-tools-proxy.sh" --remove
    [[ "$status" -eq 0 ]]
}

# =====================================================================
#  env/include-paths.sh — add2path function
# =====================================================================

@test "add2path: adds existing directory to PATH" {
    local testdir="$TMPDIR/add2path-test"
    mkdir -p "$testdir"
    local old_path="$PATH"

    # Source just the function definition (not the file-reading loop)
    eval "$(sed -n '1,/^while/{ /^while/!p }' "$REPO_DIR/env/include-paths.sh")"
    HOME="$TMPDIR" add2path "$testdir"
    [[ ":$PATH:" == *":$testdir:"* ]]
    export PATH="$old_path"
}

@test "add2path: resolves relative path under HOME" {
    local testdir="$TMPDIR/reldir"
    mkdir -p "$testdir"
    local old_path="$PATH"

    eval "$(sed -n '1,/^while/{ /^while/!p }' "$REPO_DIR/env/include-paths.sh")"
    HOME="$TMPDIR" add2path "reldir"
    [[ ":$PATH:" == *":$TMPDIR/reldir:"* ]]
    export PATH="$old_path"
}

@test "add2path: skips nonexistent directory" {
    local old_path="$PATH"
    eval "$(sed -n '1,/^while/{ /^while/!p }' "$REPO_DIR/env/include-paths.sh")"
    HOME="$TMPDIR" add2path "no-such-dir-xyz"
    [[ ":$PATH:" != *":$TMPDIR/no-such-dir-xyz:"* ]]
    export PATH="$old_path"
}

@test "add2path: no duplicate entries" {
    local testdir="$TMPDIR/dup-dir"
    mkdir -p "$testdir"
    local old_path="$PATH"

    eval "$(sed -n '1,/^while/{ /^while/!p }' "$REPO_DIR/env/include-paths.sh")"
    HOME="$TMPDIR" add2path "$testdir"
    local first_path="$PATH"
    HOME="$TMPDIR" add2path "$testdir"
    [[ "$PATH" == "$first_path" ]]
    export PATH="$old_path"
}

# =====================================================================
#  env/env-vars.sh — environment variable exports
# =====================================================================

@test "env-vars: exports EDITOR" {
    run bash -c "export HOME='$FAKE_HOME'; source '$REPO_DIR/env/env-vars.sh'; echo \$EDITOR"
    [[ "$output" == "vim" ]]
}

@test "env-vars: exports DOTFILES" {
    run bash -c "export HOME='$FAKE_HOME'; source '$REPO_DIR/env/env-vars.sh'; echo \$DOTFILES"
    [[ "$output" == "$FAKE_HOME/dotfiles" ]]
}

@test "env-vars: exports GOPATH" {
    run bash -c "export HOME='$FAKE_HOME'; source '$REPO_DIR/env/env-vars.sh'; echo \$GOPATH"
    [[ "$output" == "$FAKE_HOME/go" ]]
}

@test "env-vars: exports DOCKER_BUILDKIT=1" {
    run bash -c "export HOME='$FAKE_HOME'; source '$REPO_DIR/env/env-vars.sh'; echo \$DOCKER_BUILDKIT"
    [[ "$output" == "1" ]]
}

# =====================================================================
#  .profile — sourcability and key exports
# =====================================================================

@test "profile: sources without error" {
    run bash -c "export HOME='$FAKE_HOME'; source '$REPO_DIR/.profile' 2>/dev/null; echo ok"
    [[ "$output" == *"ok"* ]]
}

@test "profile: sets XDG_CONFIG_HOME" {
    run bash -c "export HOME='$FAKE_HOME'; source '$REPO_DIR/.profile' 2>/dev/null; echo \$XDG_CONFIG_HOME"
    [[ "$output" == "$FAKE_HOME/.config" ]]
}

@test "profile: sets XDG_CACHE_HOME" {
    run bash -c "export HOME='$FAKE_HOME'; source '$REPO_DIR/.profile' 2>/dev/null; echo \$XDG_CACHE_HOME"
    [[ "$output" == "$FAKE_HOME/.cache" ]]
}

@test "profile: sets XDG_DATA_HOME" {
    run bash -c "export HOME='$FAKE_HOME'; source '$REPO_DIR/.profile' 2>/dev/null; echo \$XDG_DATA_HOME"
    [[ "$output" == "$FAKE_HOME/.local/share" ]]
}

# =====================================================================
#  helpers/ls-path — PATH splitting
# =====================================================================

@test "ls-path: lists PATH entries one per line" {
    run env PATH="/usr/bin:/usr/local/bin:/tmp/test" bash "$REPO_DIR/helpers/ls-path"
    [[ "$status" -eq 0 ]]
    [[ "${lines[0]}" == "/usr/bin" ]]
    [[ "${lines[1]}" == "/usr/local/bin" ]]
    [[ "${lines[2]}" == "/tmp/test" ]]
}

@test "ls-path: handles single PATH entry" {
    # Must include a dir containing bash for the script to run
    local bash_dir
    bash_dir="$(dirname "$(command -v bash)")"
    run env PATH="/only/one:$bash_dir" bash "$REPO_DIR/helpers/ls-path"
    [[ "$status" -eq 0 ]]
    [[ "${lines[0]}" == "/only/one" ]]
    [[ "${lines[1]}" == "$bash_dir" ]]
}
