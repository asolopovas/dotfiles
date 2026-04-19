#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { printf '\033[0;32m%s\033[0m\n' "$*"; }
err() { printf '\033[0;31m%s\033[0m\n' "$*" >&2; }

if ! command -v bats &>/dev/null; then
    err "bats not found. Install: sudo apt install bats"
    exit 1
fi

SUITES=(
    "$SCRIPT_DIR/test-globals.bats"
    "$SCRIPT_DIR/test-scripts.bats"
    "$SCRIPT_DIR/test-init.bats"
    "$SCRIPT_DIR/test-sync-ai.bats"
    "$SCRIPT_DIR/test-inst-opencode.bats"
    "$SCRIPT_DIR/test-inst-picom.bats"
    "$SCRIPT_DIR/test-lint.bats"
)

case "${1:-}" in
    globals)
        SUITES=("$SCRIPT_DIR/test-globals.bats")
        ;;
    scripts)
        SUITES=("$SCRIPT_DIR/test-scripts.bats")
        ;;
    init)
        SUITES=("$SCRIPT_DIR/test-init.bats")
        ;;
    sync-ai)
        SUITES=("$SCRIPT_DIR/test-sync-ai.bats")
        ;;
    inst-opencode)
        SUITES=("$SCRIPT_DIR/test-inst-opencode.bats")
        ;;
    inst-picom)
        SUITES=("$SCRIPT_DIR/test-inst-picom.bats")
        ;;
    lint)
        SUITES=("$SCRIPT_DIR/test-lint.bats")
        ;;
    -*)
        exec bats "$@" "${SUITES[@]}"
        ;;
    "")
        ;; # run all
    *)
        err "Unknown suite: $1"
        echo "Usage: $0 [globals|scripts|sync-ai|inst-opencode|inst-picom|lint|-f pattern]"
        exit 1
        ;;
esac

PASS=0
FAIL=0

for suite in "${SUITES[@]}"; do
    name=$(basename "$suite" .bats)
    log "--- $name ---"
    if bats "$suite"; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
    fi
done

total=$((PASS + FAIL))
echo ""
if [ "$FAIL" -gt 0 ]; then
    err "RESULT: $PASS/$total suites passed ($FAIL failed)"
    exit 1
else
    log "RESULT: $PASS/$total suites passed"
fi
