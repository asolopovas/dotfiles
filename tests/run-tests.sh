#!/usr/bin/env bash
set -euo pipefail

# Test runner for dotfiles tests

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Running dotfiles tests...${NC}"
echo "=========================="

# Track test results
TOTAL_TESTS=0
PASSED_TESTS=0

# Find and run all test scripts
for test_script in "$SCRIPT_DIR"/test-*.sh; do
    if [[ -f "$test_script" && -x "$test_script" ]]; then
        test_name=$(basename "$test_script" .sh)
        echo -e "${YELLOW}Running $test_name...${NC}"
        
        TOTAL_TESTS=$((TOTAL_TESTS + 1))
        
        if "$test_script"; then
            echo -e "${GREEN}✓ $test_name PASSED${NC}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            echo -e "${RED}✗ $test_name FAILED${NC}"
        fi
        
        echo
    fi
done

echo "=========================="
echo "Test Results: $PASSED_TESTS/$TOTAL_TESTS passed"

if [[ $PASSED_TESTS -eq $TOTAL_TESTS ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi