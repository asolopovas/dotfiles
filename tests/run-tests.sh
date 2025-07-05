#!/usr/bin/env bash
set -euo pipefail

# Compact test runner for dotfiles tests
# Usage: run-tests.sh [--root]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Pass through arguments to test scripts
TEST_ARGS=("$@")

echo -e "${YELLOW}Running dotfiles tests...${NC}"

# Track results
TOTAL_TESTS=0
PASSED_TESTS=0

# Run all test scripts
for test_script in "$SCRIPT_DIR"/test-*.sh; do
    if [[ -f "$test_script" && -x "$test_script" ]]; then
        test_name=$(basename "$test_script" .sh)
        
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        
        echo -e "${YELLOW}$test_name${NC}"
        if "$test_script" "${TEST_ARGS[@]}"; then
            PASSED_TESTS=$((PASSED_TESTS + 1))
        fi
        echo
    fi
done

echo "Overall Results: $PASSED_TESTS/$TOTAL_TESTS test suites passed"

if [[ $PASSED_TESTS -eq $TOTAL_TESTS ]]; then
    echo -e "${GREEN}All test suites passed!${NC}"
    exit 0
else
    echo -e "${RED}Some test suites failed!${NC}"
    exit 1
fi