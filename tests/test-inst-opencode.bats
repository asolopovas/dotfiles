#!/usr/bin/env bats

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

bats_require_minimum_version 1.5.0

setup() {
    FAKE_HOME="$(mktemp -d)"
    export FAKE_HOME
    TMPDIR="$(mktemp -d)"
    export TMPDIR
    export FAKE_BIN="$TMPDIR/fake-bin"
    mkdir -p "$FAKE_BIN"
    printf '#!/bin/sh\necho "0.0.0-test"\n' >"$FAKE_BIN/opencode"
    printf '#!/bin/sh\nexit 0\n' >"$FAKE_BIN/curl"
    printf '#!/bin/sh\necho "FAIL: bunx called" >&2; exit 1\n' >"$FAKE_BIN/bunx"
    cat >"$FAKE_BIN/grep" <<'GREP'
#!/bin/sh
if [ "$1" = "-qi" ] && [ "$2" = "microsoft" ]; then
    exit 1
fi
exec /usr/bin/grep "$@"
GREP
    chmod +x "$FAKE_BIN/opencode" "$FAKE_BIN/curl" "$FAKE_BIN/bunx" "$FAKE_BIN/grep"
    mkdir -p "$FAKE_HOME/dotfiles/.config/opencode" "$FAKE_HOME/dotfiles/scripts"
    echo '{}' >"$FAKE_HOME/dotfiles/.config/opencode/opencode.jsonc"
    cat >"$FAKE_HOME/dotfiles/globals.sh" <<'G'
cmd_exist() { command -v "$1" &>/dev/null; }
print_color() { shift; echo "$*"; }
G
    cat >"$FAKE_HOME/dotfiles/scripts/sync-ai.sh" <<'S'
#!/bin/bash
set -euo pipefail
printf '%s %s\n' "${SYNC_TARGETS:-}" "$*" > "$HOME/sync-ai.args"
S
    chmod +x "$FAKE_HOME/dotfiles/scripts/sync-ai.sh"
    export PATH="$FAKE_BIN:$PATH"
    export HOME="$FAKE_HOME"
    export DOTFILES_DIR="$FAKE_HOME/dotfiles"
}

teardown() {
    rm -rf "$FAKE_HOME" "$TMPDIR"
}

opencode_run() {
    bash "$REPO_DIR/scripts/inst/inst-opencode.sh"
}

@test "opencode: skips installed binary and delegates config sync" {
    run opencode_run
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"already installed"* ]]
    [[ "$(cat "$FAKE_HOME/sync-ai.args")" == "opencode config" ]]
    [[ "$output" == *"sync-ai.sh"* ]]
}

@test "opencode: does not install skills or call bunx" {
    run opencode_run
    [[ "$status" -eq 0 ]]
    [ ! -d "$FAKE_HOME/.config/opencode/skills" ]
    [[ "$output" != *"Installing OpenCode skills"* ]]
}

@test "opencode: attempts install when binary is missing" {
    rm -f "$FAKE_BIN/opencode"
    local filtered="" IFS=':'
    for dir in $PATH; do
        [[ -x "$dir/opencode" ]] || filtered="${filtered:+$filtered:}$dir"
    done
    run env PATH="$FAKE_BIN:$filtered" /bin/bash "$REPO_DIR/scripts/inst/inst-opencode.sh"
    [[ "$output" == *"Installing OpenCode"* ]]
}
