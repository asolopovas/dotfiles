#!/usr/bin/env bats

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="$REPO_DIR/scripts/ui-terminal-toggle"
STATE_FILE="$HOME/.cache/ui-terminal-toggle-state"

require_ui() {
    command -v wmctrl >/dev/null || skip "wmctrl unavailable"
    command -v xdotool >/dev/null || skip "xdotool unavailable"
    command -v alacritty >/dev/null || skip "alacritty unavailable"
}

terminal_count() {
    wmctrl -l | grep -c Alacritty || true
}

wait_for_count() {
    local expected="$1"
    local i
    for i in {1..20}; do
        [ "$(terminal_count)" -eq "$expected" ] && return 0
        sleep 0.2
    done
    return 1
}

teardown() {
    pkill -f alacritty 2>/dev/null || true
    rm -f "$STATE_FILE"
}

@test "terminal-toggle: script is valid" {
    [ -x "$SCRIPT" ]
    run bash -n "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "terminal-toggle: direct toggle creates and tracks a terminal" {
    require_ui
    make -C "$REPO_DIR" kill-alacritty >/dev/null 2>&1 || true
    rm -f "$STATE_FILE"
    run bash "$SCRIPT" toggle
    [ "$status" -eq 0 ]
    wait_for_count 1
    [ -f "$STATE_FILE" ]
}
