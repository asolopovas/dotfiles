#!/bin/bash

# Run all tests for install-squid.sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

run_test() {
    local test_name="$1"
    local test_script="$2"
    
    ((TOTAL_TESTS++))
    log_info "Running: $test_name"
    
    if [[ ! -f "$test_script" ]]; then
        log_warn "Test script not found: $test_script"
        return 1
    fi
    
    if [[ ! -x "$test_script" ]]; then
        chmod +x "$test_script"
    fi
    
    if "$test_script" >/dev/null 2>&1; then
        log_pass "$test_name"
        ((PASSED_TESTS++))
        return 0
    else
        log_fail "$test_name"
        ((FAILED_TESTS++))
        return 1
    fi
}

main() {
    echo "========================================="
    echo "    Squid Installation Script Test Suite"
    echo "========================================="
    echo
    
    # Test basic script validation
    log_info "Testing basic script validation..."
    
    local install_script="$SCRIPT_DIR/../../scripts/install-squid.sh"
    
    if [[ ! -f "$install_script" ]]; then
        log_fail "Install script not found: $install_script"
        exit 1
    fi
    
    if ! bash -n "$install_script"; then
        log_fail "Install script has syntax errors"
        exit 1
    fi
    
    log_pass "Install script syntax is valid"
    echo
    
    # Run individual function tests
    log_info "Running function tests..."
    echo
    
    run_test "Utility Functions Test" "$SCRIPT_DIR/test_utility_functions.sh"
    run_test "Cleanup Functions Test" "$SCRIPT_DIR/test_cleanup_functions.sh"
    run_test "Install Dependencies Test" "$SCRIPT_DIR/test_install_deps.sh"
    run_test "Build Squid Test" "$SCRIPT_DIR/test_build_squid.sh"
    
    echo
    echo "========================================="
    echo "               SUMMARY"
    echo "========================================="
    echo "Total tests run: $TOTAL_TESTS"
    echo "Tests passed: $PASSED_TESTS"
    echo "Tests failed: $FAILED_TESTS"
    echo
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        log_pass "All tests passed! ✅"
        echo
        echo "The install-squid.sh script functions are working correctly."
        echo "Key findings:"
        echo "• All utility functions (log, error, run_as_user, run_as_proxy) work properly"
        echo "• Cleanup functions handle service stopping and file removal"
        echo "• Dependency installation manages apt packages and proxy user creation"
        echo "• Build process follows standard configure/make/install pattern"
        echo
        exit 0
    else
        log_fail "Some tests failed! ❌"
        echo
        echo "Please check the failed tests above for details."
        echo "Most failures are likely due to missing dependencies or"
        echo "differences between the test environment and production."
        echo
        exit 1
    fi
}

main "$@"