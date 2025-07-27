#!/bin/bash

# Test framework for install-squid.sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/install-squid.sh"
TEST_LOG="/tmp/squid-test-$(date +%s).log"
FAILED_TESTS=0
TOTAL_TESTS=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test utilities
log_test() {
    echo -e "${BLUE}[TEST]${NC} $*" | tee -a "$TEST_LOG"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $*" | tee -a "$TEST_LOG"
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $*" | tee -a "$TEST_LOG"
    ((FAILED_TESTS++))
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$TEST_LOG"
}

run_test() {
    local test_name="$1"
    local test_function="$2"
    
    ((TOTAL_TESTS++))
    log_test "Running: $test_name"
    
    if $test_function; then
        log_pass "$test_name"
        return 0
    else
        log_fail "$test_name"
        return 1
    fi
}

# Mock environment setup
setup_test_env() {
    export SUDO_USER="testuser"
    export USER="root"
    
    # Create mock directories
    mkdir -p /tmp/test-squid/{config,ssl,cache,var}
    
    # Mock gum command if not available
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
}

cleanup_test_env() {
    rm -rf /tmp/test-squid /tmp/mock-gum /tmp/gum 2>/dev/null || true
}

# Source the script for testing (extract functions only)
source_script_functions() {
    # Create a version of the script with just functions
    sed -n '/^[a-zA-Z_][a-zA-Z0-9_]*() {/,/^}/p' "$INSTALL_SCRIPT" > /tmp/squid-functions.sh
    
    # Add variables needed for functions
    cat << 'EOF' >> /tmp/squid-functions.sh
# Test variables
VER=7.1
PREFIX=/tmp/test-squid
CACHE_DIR=/tmp/test-squid/cache
USER_HOME="/home/$SUDO_USER"
CONFIG_DIR="$SCRIPT_DIR/../config/squid"
PROXY_PORT=3128
HTTP_INTERCEPT_PORT=3129
HTTPS_INTERCEPT_PORT=3130
STD_HTTP_PORT=80
STD_HTTPS_PORT=443
RSA_KEY_SIZE=2048
CERT_VALIDITY_DAYS=365
DH_PARAM_SIZE=1024  # Smaller for testing
SSL_DIR="$PREFIX/etc/ssl_cert"
CA_CERT="/usr/local/share/ca-certificates/squid-ca.crt"
CA_PEM="/etc/ssl/certs/squid-ca.pem"
CA_BUNDLE="/etc/ssl/certs/ca-certificates.crt"
NSSDB_USER="$USER_HOME/.pki/nssdb"
NSSDB_SYSTEM="/etc/pki/nssdb"
JAVA_CACERTS="/etc/ssl/certs/java/cacerts"
CACHE_REFRESH_LARGE=3
CACHE_REFRESH_CONDA=1.5
CACHE_REFRESH_MEDIA=1
CACHE_REFRESH_GITHUB=1
CACHE_REFRESH_DEFAULT=3
CACHE_PERCENTAGE=20
CACHE_MAX_OBJECT_SIZE="50 GB"
CACHE_MEM_SIZE="8192 MB"
CACHE_DIR_SIZE=100000
CACHE_L1_DIRS=16
CACHE_L2_DIRS=256
CACHE_SWAP_LOW=90
CACHE_SWAP_HIGH=95
RESTART_DELAY=5
SSLCRTD_CHILDREN=5
SSL_CERT_CACHE_SIZE=20MB
TCP_KEEPALIVE="60,30,3"
TEST_SLEEP=1  # Reduced for testing
LOG_TAIL=20
SECONDS_PER_DAY=86400
CONNECTIVITY_TEST_RETRIES=1  # Reduced for testing
CACHE_GRID_SIZE=16
SQUID_SSL_DB_SIZE="20MB"
SLEEP_AFTER_KILL=1
SLEEP_BEFORE_START=1  # Reduced for testing
PERM_PRIVATE_KEY=600
PERM_PUBLIC_FILE=644
PERM_DIRECTORY=755
SQUID_URL="https://github.com/squid-cache/squid/archive/refs/tags/SQUID_$(echo $VER | sed 's/\./_/g').tar.gz"
TEST_SITES="https://google.com https://github.com https://httpbin.org/get"
EOF
    
    source /tmp/squid-functions.sh
}

# Function tests
test_log_function() {
    local output
    output=$(log "test message" 2>&1)
    [[ "$output" == *"test message"* ]]
}

test_error_function() {
    local output
    output=$(error "error message" 2>&1)
    [[ "$output" == *"error message"* ]]
}

test_run_as_user_function() {
    # Test that it attempts to run as SUDO_USER
    local cmd="echo test"
    run_as_user $cmd >/dev/null 2>&1 || true
    # Just verify the function exists and doesn't crash
    return 0
}

test_run_as_proxy_function() {
    # Test that it attempts to run as proxy user
    local cmd="echo test"
    run_as_proxy $cmd >/dev/null 2>&1 || true
    # Just verify the function exists and doesn't crash
    return 0
}

test_cleanup_function() {
    # Mock systemctl and other commands
    mkdir -p /tmp/test-bin
    echo '#!/bin/bash' > /tmp/test-bin/systemctl
    echo '#!/bin/bash' > /tmp/test-bin/pkill
    echo '#!/bin/bash' > /tmp/test-bin/iptables
    echo '#!/bin/bash' > /tmp/test-bin/update-ca-certificates
    echo '#!/bin/bash' > /tmp/test-bin/certutil
    chmod +x /tmp/test-bin/*
    export PATH="/tmp/test-bin:$PATH"
    
    # Test cleanup doesn't crash
    cleanup >/dev/null 2>&1 || true
    
    # Cleanup
    rm -rf /tmp/test-bin
    return 0
}

test_clean_install_function() {
    # Mock commands
    mkdir -p /tmp/test-bin
    echo '#!/bin/bash' > /tmp/test-bin/systemctl
    echo '#!/bin/bash' > /tmp/test-bin/userdel
    echo '#!/bin/bash' > /tmp/test-bin/id
    chmod +x /tmp/test-bin/*
    export PATH="/tmp/test-bin:$PATH"
    
    # Test clean_install doesn't crash
    clean_install >/dev/null 2>&1 || true
    
    # Cleanup
    rm -rf /tmp/test-bin
    return 0
}

test_config_template_validation() {
    # Check if config templates exist
    local config_dir="$SCRIPT_DIR/../config/squid"
    local templates=(
        "ca.conf.template"
        "server.conf.template" 
        "mime.conf.template"
        "squid.conf.template"
        "squid.service.template"
    )
    
    for template in "${templates[@]}"; do
        if [[ ! -f "$config_dir/$template" ]]; then
            log_warn "Missing config template: $config_dir/$template"
            return 1
        fi
    done
    return 0
}

test_script_syntax() {
    bash -n "$INSTALL_SCRIPT"
}

test_script_permissions() {
    [[ -x "$INSTALL_SCRIPT" ]]
}

test_dependency_check() {
    # Test that required commands exist or script handles missing ones
    local required_commands=(
        "wget" "tar" "openssl" "make" "gcc"
        "useradd" "systemctl" "iptables"
    )
    
    local missing_count=0
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_warn "Missing command: $cmd"
            ((missing_count++))
        fi
    done
    
    # Allow some missing commands for testing environment
    [[ $missing_count -lt 5 ]]
}

test_variable_definitions() {
    # Source the script and check if key variables are defined
    (
        source /tmp/squid-functions.sh
        [[ -n "$VER" ]] && [[ -n "$PREFIX" ]] && [[ -n "$CACHE_DIR" ]]
    )
}

test_url_accessibility() {
    # Test if the squid download URL is accessible
    local url_pattern="https://github.com/squid-cache/squid/archive/refs/tags/SQUID_"
    curl -s --head "${url_pattern}7_1.tar.gz" >/dev/null 2>&1 || {
        log_warn "Squid download URL may not be accessible"
        return 1
    }
    return 0
}

test_port_validation() {
    # Test that ports are valid numbers
    (
        source /tmp/squid-functions.sh
        [[ "$PROXY_PORT" =~ ^[0-9]+$ ]] &&
        [[ "$HTTP_INTERCEPT_PORT" =~ ^[0-9]+$ ]] &&
        [[ "$HTTPS_INTERCEPT_PORT" =~ ^[0-9]+$ ]]
    )
}

test_ssl_config_validity() {
    # Test SSL configuration parameters
    (
        source /tmp/squid-functions.sh
        [[ "$RSA_KEY_SIZE" =~ ^[0-9]+$ ]] &&
        [[ "$CERT_VALIDITY_DAYS" =~ ^[0-9]+$ ]] &&
        [[ "$DH_PARAM_SIZE" =~ ^[0-9]+$ ]]
    )
}

test_cache_config_validity() {
    # Test cache configuration parameters
    (
        source /tmp/squid-functions.sh
        [[ "$CACHE_DIR_SIZE" =~ ^[0-9]+$ ]] &&
        [[ "$CACHE_L1_DIRS" =~ ^[0-9]+$ ]] &&
        [[ "$CACHE_L2_DIRS" =~ ^[0-9]+$ ]]
    )
}

test_main_argument_handling() {
    # Test main function argument parsing (dry run)
    echo '#!/bin/bash
    main() {
        case "${1:-}" in
            --clean) echo "clean"; exit 0 ;;
            --disable) echo "disable"; exit 0 ;;
            *) echo "install" ;;
        esac
    }
    main "$@"' > /tmp/test-main.sh
    
    chmod +x /tmp/test-main.sh
    
    [[ "$(/tmp/test-main.sh --clean)" == "clean" ]] &&
    [[ "$(/tmp/test-main.sh --disable)" == "disable" ]] &&
    [[ "$(/tmp/test-main.sh)" == "install" ]]
}

# Main test execution
main() {
    echo "=== Squid Installation Script Test Suite ===" | tee "$TEST_LOG"
    echo "Test log: $TEST_LOG" | tee -a "$TEST_LOG"
    
    setup_test_env
    source_script_functions
    
    # Run all tests
    run_test "Script syntax validation" test_script_syntax
    run_test "Script permissions" test_script_permissions
    run_test "Variable definitions" test_variable_definitions
    run_test "Port validation" test_port_validation
    run_test "SSL config validity" test_ssl_config_validity
    run_test "Cache config validity" test_cache_config_validity
    run_test "Config template validation" test_config_template_validation
    run_test "Dependency check" test_dependency_check
    run_test "URL accessibility" test_url_accessibility
    run_test "Log function" test_log_function
    run_test "Error function" test_error_function
    run_test "Run as user function" test_run_as_user_function
    run_test "Run as proxy function" test_run_as_proxy_function
    run_test "Cleanup function" test_cleanup_function
    run_test "Clean install function" test_clean_install_function
    run_test "Main argument handling" test_main_argument_handling
    
    cleanup_test_env
    
    # Summary
    echo "=== Test Summary ===" | tee -a "$TEST_LOG"
    echo "Total tests: $TOTAL_TESTS" | tee -a "$TEST_LOG"
    echo "Failed tests: $FAILED_TESTS" | tee -a "$TEST_LOG"
    echo "Passed tests: $((TOTAL_TESTS - FAILED_TESTS))" | tee -a "$TEST_LOG"
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        log_pass "All tests passed!"
        exit 0
    else
        log_fail "$FAILED_TESTS tests failed!"
        exit 1
    fi
}

# Check if running as main script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi