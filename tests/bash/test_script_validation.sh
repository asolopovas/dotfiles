#!/bin/bash

# Basic script validation tests
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/../../scripts/install-squid.sh"
TEST_LOG="/tmp/squid-validation-test-$(date +%s).log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_test() { echo -e "${BLUE}[TEST]${NC} $*" | tee -a "$TEST_LOG"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $*" | tee -a "$TEST_LOG"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $*" | tee -a "$TEST_LOG"; }

test_script_exists() {
    log_test "Testing script exists"
    
    if [[ -f "$INSTALL_SCRIPT" ]]; then
        log_pass "Script exists at $INSTALL_SCRIPT"
        return 0
    else
        log_fail "Script not found at $INSTALL_SCRIPT"
        return 1
    fi
}

test_script_executable() {
    log_test "Testing script is executable"
    
    if [[ -x "$INSTALL_SCRIPT" ]]; then
        log_pass "Script is executable"
        return 0
    else
        log_fail "Script is not executable"
        return 1
    fi
}

test_script_syntax() {
    log_test "Testing script syntax"
    
    if bash -n "$INSTALL_SCRIPT" 2>/dev/null; then
        log_pass "Script syntax is valid"
        return 0
    else
        log_fail "Script has syntax errors"
        return 1
    fi
}

test_required_functions() {
    log_test "Testing required functions exist"
    
    local required_functions=(
        "log"
        "error" 
        "cleanup"
        "install_deps"
        "build_squid"
        "create_certs"
        "start_squid"
        "main"
    )
    
    local missing_functions=()
    
    for func in "${required_functions[@]}"; do
        if ! grep -q "^${func}() {" "$INSTALL_SCRIPT"; then
            missing_functions+=("$func")
        fi
    done
    
    if [[ ${#missing_functions[@]} -eq 0 ]]; then
        log_pass "All required functions exist"
        return 0
    else
        log_fail "Missing functions: ${missing_functions[*]}"
        return 1
    fi
}

test_required_variables() {
    log_test "Testing required variables are defined"
    
    local required_vars=(
        "VER"
        "PREFIX"
        "CACHE_DIR"
        "PROXY_PORT"
        "SSL_DIR"
    )
    
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if ! grep -q "^${var}=" "$INSTALL_SCRIPT"; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -eq 0 ]]; then
        log_pass "All required variables are defined"
        return 0
    else
        log_fail "Missing variables: ${missing_vars[*]}"
        return 1
    fi
}

test_sudo_checks() {
    log_test "Testing sudo requirement checks"
    
    if grep -q 'id -u.*!= "0"' "$INSTALL_SCRIPT" && 
       grep -q 'SUDO_USER' "$INSTALL_SCRIPT" &&
       grep -q 'exec sudo' "$INSTALL_SCRIPT"; then
        log_pass "Script has proper sudo checks and auto-elevation"
        return 0
    else
        log_fail "Script missing sudo requirement checks or auto-elevation"
        return 1
    fi
}

test_config_templates() {
    log_test "Testing config template references"
    
    local config_dir="$SCRIPT_DIR/../../config/squid"
    local templates=(
        "ca.conf.template"
        "server.conf.template"
        "squid.conf.template"
        "squid.service.template"
    )
    
    local missing_templates=()
    
    for template in "${templates[@]}"; do
        if [[ ! -f "$config_dir/$template" ]]; then
            missing_templates+=("$template")
        fi
    done
    
    if [[ ${#missing_templates[@]} -eq 0 ]]; then
        log_pass "All config templates exist"
        return 0
    else
        log_fail "Missing templates: ${missing_templates[*]}"
        return 1
    fi
}

main() {
    echo "=== Script Validation Test ===" | tee "$TEST_LOG"
    
    local failed=0
    
    test_script_exists || ((failed++))
    test_script_executable || ((failed++))
    test_script_syntax || ((failed++))
    test_required_functions || ((failed++))
    test_required_variables || ((failed++))
    test_sudo_checks || ((failed++))
    test_config_templates || ((failed++))
    
    echo "=== Results ===" | tee -a "$TEST_LOG"
    if [[ $failed -eq 0 ]]; then
        log_pass "All validation tests passed!"
        exit 0
    else
        log_fail "$failed validation tests failed!"
        exit 1
    fi
}

main "$@"