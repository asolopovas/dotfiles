#!/usr/bin/env bats

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    FAKE_HOME="$(mktemp -d)"
    export FAKE_HOME
    TMPDIR="$(mktemp -d)"
    export TMPDIR
    export FAKE_BIN="$TMPDIR/fake-bin"
    mkdir -p "$FAKE_BIN"
    printf '#!/bin/sh\nwhile [ $# -gt 0 ]; do case "$1" in -n|-E) shift;; -*) shift;; *) break;; esac; done\n"$@"\n' >"$FAKE_BIN/sudo"
    chmod +x "$FAKE_BIN/sudo"
    mkdir -p "$FAKE_HOME/dotfiles/.config/fish" "$FAKE_HOME/dotfiles/.config/nvim" "$FAKE_HOME/dotfiles/.config/tmux" "$FAKE_HOME/dotfiles/.config/claude/commands"
    touch "$FAKE_HOME/dotfiles/.config/.aliasrc" "$FAKE_HOME/dotfiles/.config/.func"
    echo '{"key": "val"}' >"$FAKE_HOME/dotfiles/.config/claude/settings.json"
}

teardown() {
    rm -rf "$FAKE_HOME" "$TMPDIR"
}

symlinks_run() {
    env -u XDG_CONFIG_HOME HOME="$FAKE_HOME" DOTFILES_DIR="$FAKE_HOME/dotfiles" bash "$REPO_DIR/scripts/ops/ops-update-symlinks.sh"
}

source_add2path() {
    eval "$(sed -n '1,/^while/{ /^while/!p }' "$REPO_DIR/env/include-paths.sh")"
}

@test "symlinks: creates expected links and is idempotent" {
    symlinks_run
    [ -L "$FAKE_HOME/.config/fish" ]
    [ -L "$FAKE_HOME/.config/nvim" ]
    [ -L "$FAKE_HOME/.config/tmux" ]
    [ -L "$FAKE_HOME/.config/.aliasrc" ]
    [ -L "$FAKE_HOME/.config/.func" ]
    [ -L "$FAKE_HOME/.claude/settings.json" ]
    [ -L "$FAKE_HOME/.claude/commands" ]
    [[ "$(readlink "$FAKE_HOME/.config/nvim")" == "$FAKE_HOME/dotfiles/.config/nvim" ]]
    run symlinks_run
    [[ "$status" -eq 0 ]]
}

@test "symlinks: replaces stale symlinks" {
    mkdir -p "$FAKE_HOME/.config"
    ln -s /old/target "$FAKE_HOME/.config/nvim"
    symlinks_run
    [[ "$(readlink "$FAKE_HOME/.config/nvim")" == "$FAKE_HOME/dotfiles/.config/nvim" ]]
}

@test "symlinks: rejects repo XDG_CONFIG_HOME" {
    run env XDG_CONFIG_HOME="$FAKE_HOME/dotfiles/.config" HOME="$FAKE_HOME" DOTFILES_DIR="$FAKE_HOME/dotfiles" bash "$REPO_DIR/scripts/ops/ops-update-symlinks.sh"
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"Refusing"* ]]
}

@test "symlinks: respects custom XDG_CONFIG_HOME" {
    local custom_xdg="$TMPDIR/custom-config"
    mkdir -p "$custom_xdg"
    env -u XDG_CONFIG_HOME HOME="$FAKE_HOME" DOTFILES_DIR="$FAKE_HOME/dotfiles" XDG_CONFIG_HOME="$custom_xdg" bash "$REPO_DIR/scripts/ops/ops-update-symlinks.sh"
    [ -L "$custom_xdg/fish" ]
    [ -L "$custom_xdg/nvim" ]
    [ -L "$custom_xdg/tmux" ]
}

@test "add2path: handles absolute, relative, missing, and duplicate paths" {
    local abs="$TMPDIR/add2path-test"
    local rel="$TMPDIR/reldir"
    local old_path="$PATH"
    mkdir -p "$abs" "$rel"
    source_add2path
    HOME="$TMPDIR" add2path "$abs"
    HOME="$TMPDIR" add2path "reldir"
    HOME="$TMPDIR" add2path "no-such-dir-xyz"
    [[ ":$PATH:" == *":$abs:"* ]]
    [[ ":$PATH:" == *":$rel:"* ]]
    [[ ":$PATH:" != *":$TMPDIR/no-such-dir-xyz:"* ]]
    local first_path="$PATH"
    HOME="$TMPDIR" add2path "$abs"
    [[ "$PATH" == "$first_path" ]]
    export PATH="$old_path"
}

@test "env-vars: exports expected values" {
    run bash -c "export HOME='$FAKE_HOME'; source '$REPO_DIR/env/env-vars.sh'; printf '%s\n' \"\$EDITOR\" \"\$DOTFILES\" \"\$GOPATH\" \"\$DOCKER_BUILDKIT\""
    [[ "${lines[0]}" == "vim" ]]
    [[ "${lines[1]}" == "$FAKE_HOME/dotfiles" ]]
    [[ "${lines[2]}" == "$FAKE_HOME/go" ]]
    [[ "${lines[3]}" == "1" ]]
}

@test "profile: sources and sets XDG paths" {
    run bash -c "export HOME='$FAKE_HOME'; source '$REPO_DIR/.profile' 2>/dev/null; printf '%s\n' ok \"\$XDG_CONFIG_HOME\" \"\$XDG_CACHE_HOME\" \"\$XDG_DATA_HOME\""
    [[ "${lines[0]}" == "ok" ]]
    [[ "${lines[1]}" == "$FAKE_HOME/.config" ]]
    [[ "${lines[2]}" == "$FAKE_HOME/.cache" ]]
    [[ "${lines[3]}" == "$FAKE_HOME/.local/share" ]]
}

@test "ls-path: lists path entries" {
    local bash_dir
    bash_dir="$(dirname "$(command -v bash)")"
    run env PATH="/usr/bin:/usr/local/bin:/tmp/test" bash "$REPO_DIR/helpers/ls-path"
    [[ "$status" -eq 0 ]]
    [[ "${lines[0]}" == "/usr/bin" ]]
    [[ "${lines[1]}" == "/usr/local/bin" ]]
    [[ "${lines[2]}" == "/tmp/test" ]]
    run env PATH="/only/one:$bash_dir" bash "$REPO_DIR/helpers/ls-path"
    [[ "$status" -eq 0 ]]
    [[ "${lines[0]}" == "/only/one" ]]
    [[ "${lines[1]}" == "$bash_dir" ]]
}

@test "fzf-code: skips missing local paths and GitHub VFS entries" {
    command -v sqlite3 >/dev/null || skip "sqlite3 unavailable"
    local code_home="$TMPDIR/code-home"
    local storage_dir="$code_home/.config/Code/User/globalStorage"
    local existing="$TMPDIR/existing-project"
    local missing="$TMPDIR/missing-project"
    local capture="$TMPDIR/fzf-input"
    mkdir -p "$storage_dir" "$existing"
    sqlite3 "$storage_dir/state.vscdb" "CREATE TABLE ItemTable (key TEXT PRIMARY KEY, value TEXT);"
    cat >"$storage_dir/storage.json" <<EOF
{"profileAssociations":{"workspaces":{"file://$existing":{},"file://$missing":{},"vscode-remote://ssh-remote+host/home/user/remote-project":{},"vscode-vfs://github+abcdef/asolopovas/github-project":{}}}}
EOF
    printf '#!/usr/bin/env bash\ncat > "$FZF_CAPTURE"\nexit 1\n' >"$FAKE_BIN/fzf"
    chmod +x "$FAKE_BIN/fzf"
    run env HOME="$code_home" PATH="$FAKE_BIN:$PATH" FZF_CAPTURE="$capture" bash "$REPO_DIR/helpers/fzf-code"
    [[ "$status" -eq 1 ]]
    [[ -f "$capture" ]]
    [[ "$(<"$capture")" == *"existing-project"* ]]
    [[ "$(<"$capture")" == *"remote-project"* ]]
    [[ "$(<"$capture")" != *"missing-project"* ]]
    [[ "$(<"$capture")" != *"github-project"* ]]
}

@test "repo: fzf selection clones selected cached repository" {
    local cache_home="$TMPDIR/cache"
    local workdir="$TMPDIR/workdir"
    local fzf_capture="$TMPDIR/repo-fzf-input"
    local git_capture="$TMPDIR/repo-git-args"
    mkdir -p "$cache_home/dotfiles" "$workdir"
    printf '%s\n' $'alpha\tAlpha repo' $'beta\tBeta repo' >"$cache_home/dotfiles/repos-example"
    printf '#!/usr/bin/env bash\ncat > "$FZF_CAPTURE"\nprintf "beta\\tBeta repo\\n"\n' >"$FAKE_BIN/fzf"
    printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$1" "$2" > "$GIT_CAPTURE"\n' >"$FAKE_BIN/git"
    chmod +x "$FAKE_BIN/fzf" "$FAKE_BIN/git"
    run env HOME="$FAKE_HOME" XDG_CACHE_HOME="$cache_home" REPO_OWNER=example PATH="$FAKE_BIN:$PATH" FZF_CAPTURE="$fzf_capture" GIT_CAPTURE="$git_capture" bash -c "cd '$workdir' && '$REPO_DIR/helpers/repo' --pick"
    [[ "$status" -eq 0 ]]
    [[ "$(<"$fzf_capture")" == *"alpha"* ]]
    [[ "$(<"$fzf_capture")" == *"beta"* ]]
    [[ "$(sed -n '1p' "$git_capture")" == "clone" ]]
    [[ "$(sed -n '2p' "$git_capture")" == "git@github.com:example/beta.git" ]]
}

@test "repo: fzf selection honors https cloning" {
    local cache_home="$TMPDIR/cache"
    local workdir="$TMPDIR/workdir"
    local git_capture="$TMPDIR/repo-git-args"
    mkdir -p "$cache_home/dotfiles" "$workdir"
    printf '%s\n' $'beta\tBeta repo' >"$cache_home/dotfiles/repos-example"
    printf '#!/usr/bin/env bash\ncat >/dev/null\nprintf "beta\\tBeta repo\\n"\n' >"$FAKE_BIN/fzf"
    printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$1" "$2" > "$GIT_CAPTURE"\n' >"$FAKE_BIN/git"
    chmod +x "$FAKE_BIN/fzf" "$FAKE_BIN/git"
    run env HOME="$FAKE_HOME" XDG_CACHE_HOME="$cache_home" REPO_OWNER=example PATH="$FAKE_BIN:$PATH" GIT_CAPTURE="$git_capture" bash -c "cd '$workdir' && '$REPO_DIR/helpers/repo' --pick --https"
    [[ "$status" -eq 0 ]]
    [[ "$(sed -n '2p' "$git_capture")" == "https://github.com/example/beta.git" ]]
}
