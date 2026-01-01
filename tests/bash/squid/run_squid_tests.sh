#!/bin/bash

# Main entry point for all Squid installation tests
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/../../../scripts/inst-squid.sh"

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

show_help() {
    echo "Squid Installation Test Suite"
    echo
    echo "Usage: $0 [OPTION]"
    echo
    echo "Options:"
    echo "  --help          Show this help message"
    echo "  --syntax        Test script syntax and structure only"
    echo "  --full          Full installation and functionality test (requires sudo)"
    echo "  --clean         Clean up test artifacts and squid installation"
    echo
    echo "Default: Run syntax tests only (safe to run without sudo)"
    echo
    echo "⚠️  WARNING: --full will install actual Squid proxy and requires sudo!"
}

run_syntax_tests() {
    log_info "Running Squid script syntax and structure tests"
    echo
    
    local failed=0
    
    # Test 1: Utility functions
    log_info "Testing utility functions..."
    if "$SCRIPT_DIR/../test_utility_simple.sh" >/dev/null 2>&1; then
        log_pass "Utility function tests passed"
    else
        log_fail "Utility function tests failed"
        ((failed++))
    fi
    
    # Test 2: Script structure analysis
    log_info "Analyzing script structure..."
    local required_functions=(
        "cleanup" "install_deps" "build_squid"
        "create_certs" "create_config" "init_cache"
        "start_squid" "create_service" "test_proxy" "main"
        "configure_dev_tools" "uninstall"
    )
    
    local missing_functions=()
    for func in "${required_functions[@]}"; do
        if ! grep -q "^${func}() {" "$INSTALL_SCRIPT"; then
            missing_functions+=("$func")
        fi
    done
    
    if [[ ${#missing_functions[@]} -eq 0 ]]; then
        log_pass "All required functions found (${#required_functions[@]} functions)"
    else
        log_fail "Missing functions: ${missing_functions[*]}"
        ((failed++))
    fi
    
    # Test 4: Configuration files check
    log_info "Checking configuration files..."
    local config_dir="$SCRIPT_DIR/../../../config/squid"
    local config_files=(
        "ca.conf.template"
        "server.conf.template"
        "mime.conf.template"
        "squid.conf.template"
        "squid.service.template"
    )
    
    local missing_configs=()
    for config in "${config_files[@]}"; do
        if [[ ! -f "$config_dir/$config" ]]; then
            missing_configs+=("$config")
        fi
    done
    
    if [[ ${#missing_configs[@]} -eq 0 ]]; then
        log_pass "All configuration templates found (${#config_files[@]} files)"
    else
        log_fail "Missing config files: ${missing_configs[*]}"
        ((failed++))
    fi
    
    echo
    return $failed
}

run_full_tests() {
    log_info "Running full Squid installation and functionality tests"
    log_warn "This will install actual Squid proxy and requires sudo privileges"
    echo
    
    # Check sudo
    if [[ $EUID -ne 0 ]]; then
        log_fail "Full tests require sudo privileges"
        echo "Run: sudo $0 --full"
        return 1
    fi
    
    if [[ -z "${SUDO_USER:-}" ]]; then
        log_fail "Must be run with sudo, not as root directly"
        echo "Run: sudo $0 --full"
        return 1
    fi
    
    # Run full functionality test
    if "$SCRIPT_DIR/test_squid_functionality.sh"; then
        log_pass "Full functionality tests passed"
        return 0
    else
        log_fail "Full functionality tests failed"
        return 1
    fi
}

clean_test_artifacts() {
    log_info "Cleaning test artifacts and Squid installation"
    
    if [[ $EUID -ne 0 ]]; then
        log_fail "Clean operation requires sudo privileges"
        echo "Run: sudo $0 --clean"
        return 1
    fi
    
    # Run script cleanup
    if [[ -x "$INSTALL_SCRIPT" ]]; then
        log_info "Running script cleanup..."
        "$INSTALL_SCRIPT" --clean 2>/dev/null || true
    fi
    
    # Additional cleanup
    rm -f /tmp/squid-*-test-*.log
    rm -rf /tmp/test-squid* /tmp/test-cache
    
    log_pass "Cleanup completed"
    return 0
}

main() {
    case "${1:-}" in
        --help|-h)
            show_help
            exit 0
            ;;
        --syntax)
            echo "=== Squid Script Syntax Tests ==="
            echo
            if run_syntax_tests; then
                echo
                log_pass "✅ All syntax tests passed!"
                exit 0
            else
                echo
                log_fail "❌ Some syntax tests failed!"
                exit 1
            fi
            ;;
        --full)
            echo "=== Full Squid Installation Test ==="
            echo
            if run_full_tests; then
                echo
                log_pass "✅ Full installation test passed!"
                exit 0
            else
                echo
                log_fail "❌ Full installation test failed!"
                exit 1
            fi
            ;;
        --clean)
            echo "=== Cleaning Squid Test Environment ==="
            echo
            if clean_test_artifacts; then
                echo
                log_pass "✅ Cleanup completed!"
                exit 0
            else
                echo
                log_fail "❌ Cleanup failed!"
                exit 1
            fi
            ;;
        "")
            # Default: run syntax tests only
            echo "=== Squid Installation Tests (Default: Syntax Only) ==="
            echo
            log_info "Running safe syntax tests (use --full for complete testing)"
            echo
            if run_syntax_tests; then
                echo
                log_pass "✅ Syntax tests passed!"
                echo
                echo "💡 To run full functionality tests: $0 --full"
                echo "🧹 To clean up test environment: $0 --clean"
                exit 0
            else
                echo
                log_fail "❌ Syntax tests failed!"
                exit 1
            fi
            ;;
        *)
            echo "Unknown option: $1"
            echo
            show_help
            exit 1
            ;;
    esac
}

# Safety check
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi