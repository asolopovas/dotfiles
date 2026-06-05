#!/usr/bin/env bats

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SNAP_WINDOW="$REPO_DIR/scripts/ui-snap-window"
TEST_WINDOW_POS="$HOME/.local/bin/test-window-position"

require_ui() {
    command -v wmctrl >/dev/null || skip "wmctrl unavailable"
    command -v xdotool >/dev/null || skip "xdotool unavailable"
    command -v xrandr >/dev/null || skip "xrandr unavailable"
    xdotool getactivewindow >/dev/null 2>&1 || skip "no active window"
}

snap() {
    require_ui
    run bash "$SNAP_WINDOW" "$1"
    [ "$status" -eq 0 ]
}

@test "ui-snap-window: scripts are present" {
    [ -x "$SNAP_WINDOW" ]
    [ -x "$TEST_WINDOW_POS" ] || [ ! -e "$TEST_WINDOW_POS" ]
    run bash -n "$SNAP_WINDOW"
    [ "$status" -eq 0 ]
}

@test "ui-snap-window: dependencies and active window are available" {
    require_ui
}

@test "ui-snap-window: cardinal directions run" {
    for direction in left right up down; do
        snap "$direction"
    done
}

@test "ui-snap-window: expansion directions run" {
    for direction in left expand-right expand-right right expand-left expand-left up expand-down down expand-up; do
        snap "$direction"
    done
}

@test "ui-snap-window: invalid direction exits cleanly" {
    run bash "$SNAP_WINDOW" invalid_direction
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}
