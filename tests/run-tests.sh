#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Local test runner — runs all bats unit tests without Docker.
# Fast (~2-5s), tests core script functionality only.
#
# Usage:
#   ./tests/run-tests.sh              Run all local test suites
#   ./tests/run-tests.sh globals      Run only globals tests
#   ./tests/run-tests.sh scripts      Run only script tests
#   ./tests/run-tests.sh -f "pattern" Pass args directly to bats
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
err()  { printf '\033[0;31m%s\033[0m\n' "$*" >&2; }

# Check bats is installed
if ! command -v bats &>/dev/null; then
    err "bats not found. Install: sudo apt install bats"
    exit 1
fi

# Local test suites (order: fast/small first)
SUITES=(
    "$SCRIPT_DIR/test-globals.bats"
    "$SCRIPT_DIR/test-scripts.bats"
)

# Handle arguments
case "${1:-}" in
    globals)
        SUITES=("$SCRIPT_DIR/test-globals.bats")
        ;;
    scripts)
        SUITES=("$SCRIPT_DIR/test-scripts.bats")
        ;;
    -*)
        # Pass all args to bats with all suites
        exec bats "$@" "${SUITES[@]}"
        ;;
    "")
        ;; # run all
    *)
        err "Unknown suite: $1"
        echo "Usage: $0 [globals|scripts|-f pattern]"
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
