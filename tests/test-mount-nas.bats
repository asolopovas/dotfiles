#!/usr/bin/env bats

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="$REPO_DIR/scripts/mount-nas.sh"

@test "mount-nas: script is valid" {
    [ -f "$SCRIPT" ]
    run bash -n "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "mount-nas: refuses non-root execution" {
    [ "$EUID" -eq 0 ] && skip "root shell"
    local home
    home="$(mktemp -d)"
    mkdir -p "$home/dotfiles"
    printf ':\n' >"$home/dotfiles/globals.sh"
    run env HOME="$home" bash "$SCRIPT" "user:pass"
    rm -rf "$home"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Please run as root"* ]]
}
