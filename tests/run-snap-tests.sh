#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_FILE="$SCRIPT_DIR/test-ui-snap-window.bats"

if ! command -v bats >/dev/null 2>&1; then
    echo "Bats not found. Install with: sudo apt install bats" >&2
    exit 1
fi

bats "$TEST_FILE"

if command -v ui-snap-window >/dev/null 2>&1 && command -v test-window-position >/dev/null 2>&1; then
    for direction in left right up down expand-right expand-left expand-up expand-down; do
        ui-snap-window "$direction"
        sleep 0.2
    done
    test-window-position >/dev/null || true
fi
