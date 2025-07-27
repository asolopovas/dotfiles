#!/bin/bash

# Simple utility function tests
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/../../scripts/install-squid.sh"
TEST_LOG="/tmp/squid-utility-simple-test-$(date +%s).log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_test() { echo -e "${BLUE}[TEST]${NC} $*" | tee -a "$TEST_LOG"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $*" | tee -a "$TEST_LOG"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $*" | tee -a "$TEST_LOG"; }

test_utility_functions_exist() {
    log_test "Testing utility functions exist in script"
    
    local functions=("log" "error" "run_as_user" "run_as_proxy")
    local missing=()
    
    for func in "${functions[@]}"; do
        if ! grep -q "^${func}() {" "$INSTALL_SCRIPT"; then
            missing+=("$func")
        fi
    done
    
    if [[ ${#missing[@]} -eq 0 ]]; then
        log_pass "All utility functions found"
        return 0
    else
        log_fail "Missing functions: ${missing[*]}"
        return 1
    fi
}

test_output_formatting() {
    log_test "Testing output formatting"
    
    if grep -q "echo.*✓" "$INSTALL_SCRIPT"; then
        log_pass "Script uses formatted output"
        return 0
    else
        log_fail "Script does not use formatted output"
        return 1
    fi
}

test_sudo_user_usage() {
    log_test "Testing SUDO_USER variable usage"
    
    if grep -q "SUDO_USER" "$INSTALL_SCRIPT"; then
        log_pass "Script uses SUDO_USER variable"
        return 0
    else
        log_fail "Script does not use SUDO_USER variable"
        return 1
    fi
}

test_error_handling() {
    log_test "Testing error handling patterns"
    
    if grep -q "set -eu" "$INSTALL_SCRIPT" || 
       grep -q "exit 1" "$INSTALL_SCRIPT"; then
        log_pass "Script has error handling"
        return 0
    else
        log_fail "Script lacks error handling"
        return 1
    fi
}

main() {
    echo "=== Simple Utility Test ===" | tee "$TEST_LOG"
    
    local failed=0
    
    test_utility_functions_exist || ((failed++))
    test_output_formatting || ((failed++))
    test_sudo_user_usage || ((failed++))
    test_error_handling || ((failed++))
    
    echo "=== Results ===" | tee -a "$TEST_LOG"
    if [[ $failed -eq 0 ]]; then
        log_pass "All utility tests passed!"
        exit 0
    else
        log_fail "$failed utility tests failed!"
        exit 1
    fi
}

main "$@"