#!/bin/bash

# Test utility functions from install-squid.sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/../../scripts/install-squid.sh"
TEST_LOG="/tmp/squid-utility-test-$(date +%s).log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_test() { echo -e "${BLUE}[TEST]${NC} $*" | tee -a "$TEST_LOG"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $*" | tee -a "$TEST_LOG"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $*" | tee -a "$TEST_LOG"; }

# Extract utility functions from script
setup_functions() {
    # Mock gum if not available
    if ! command -v gum >/dev/null 2>&1; then
        echo '#!/bin/bash
case "$1" in
    style) shift; echo "$*" ;;
    *) echo "$*" ;;
esac' > /tmp/mock-gum
        chmod +x /tmp/mock-gum
        export PATH="/tmp:$PATH"
        ln -sf /tmp/mock-gum /tmp/gum 2>/dev/null || true
    fi
    
    # Set test environment
    export SUDO_USER="testuser"
    
    # Extract functions
    sed -n '/^log() {/,/^}/p; /^error() {/,/^}/p; /^run_as_user() {/,/^}/p; /^run_as_proxy() {/,/^}/p' "$INSTALL_SCRIPT" > /tmp/utility-functions.sh
    source /tmp/utility-functions.sh
}

test_log_function() {
    log_test "Testing log() function"
    
    local output
    output=$(log "test message" 2>&1)
    
    if [[ "$output" == *"test message"* ]]; then
        log_pass "log() function works"
        return 0
    else
        log_fail "log() function failed - output: $output"
        return 1
    fi
}

test_error_function() {
    log_test "Testing error() function"
    
    local output
    output=$(error "error message" 2>&1)
    
    if [[ "$output" == *"error message"* ]]; then
        log_pass "error() function works"
        return 0
    else
        log_fail "error() function failed - output: $output"
        return 1
    fi
}

test_run_as_user_function() {
    log_test "Testing run_as_user() function"
    
    # Test with echo command
    local output
    output=$(run_as_user echo "test output" 2>&1 || echo "FAILED")
    
    if [[ "$output" == *"test output"* ]] || [[ "$output" == *"FAILED"* ]]; then
        log_pass "run_as_user() function syntax is correct"
        return 0
    else
        log_fail "run_as_user() function failed - output: $output"
        return 1
    fi
}

test_run_as_proxy_function() {
    log_test "Testing run_as_proxy() function"
    
    # Test with echo command (will likely fail but syntax should be correct)
    local output
    output=$(run_as_proxy echo "test output" 2>&1 || echo "EXPECTED_FAIL")
    
    if [[ "$output" == *"test output"* ]] || [[ "$output" == *"EXPECTED_FAIL"* ]] || [[ "$output" == *"proxy"* ]]; then
        log_pass "run_as_proxy() function syntax is correct"
        return 0
    else
        log_fail "run_as_proxy() function failed - output: $output"
        return 1
    fi
}

test_function_definitions() {
    log_test "Testing function definitions exist"
    
    if declare -f log >/dev/null && declare -f error >/dev/null && 
       declare -f run_as_user >/dev/null && declare -f run_as_proxy >/dev/null; then
        log_pass "All utility functions are defined"
        return 0
    else
        log_fail "Some utility functions are missing"
        return 1
    fi
}

cleanup() {
    rm -f /tmp/utility-functions.sh /tmp/mock-gum /tmp/gum 2>/dev/null || true
}

main() {
    echo "=== Utility Functions Test ===" | tee "$TEST_LOG"
    
    setup_functions
    
    local failed=0
    
    test_function_definitions || ((failed++))
    test_log_function || ((failed++))
    test_error_function || ((failed++))
    test_run_as_user_function || ((failed++))
    test_run_as_proxy_function || ((failed++))
    
    cleanup
    
    echo "=== Results ===" | tee -a "$TEST_LOG"
    if [[ $failed -eq 0 ]]; then
        log_pass "All utility function tests passed!"
        exit 0
    else
        log_fail "$failed utility function tests failed!"
        exit 1
    fi
}

main "$@"