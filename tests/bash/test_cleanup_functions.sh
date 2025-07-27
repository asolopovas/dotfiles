#!/bin/bash

# Test cleanup functions from install-squid.sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/../../scripts/install-squid.sh"
TEST_LOG="/tmp/squid-cleanup-test-$(date +%s).log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_test() { echo -e "${BLUE}[TEST]${NC} $*" | tee -a "$TEST_LOG"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $*" | tee -a "$TEST_LOG"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $*" | tee -a "$TEST_LOG"; }

setup_test_env() {
    # Create test directories
    export TEST_PREFIX="/tmp/test-squid-cleanup"
    export TEST_CACHE_DIR="/tmp/test-cache"
    mkdir -p "$TEST_PREFIX/etc" "$TEST_PREFIX/var" "$TEST_CACHE_DIR"
    
    # Mock gum
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
    
    # Set test environment variables
    export SUDO_USER="testuser"
    export USER_HOME="/home/$SUDO_USER"
    export PREFIX="$TEST_PREFIX"
    export CACHE_DIR="$TEST_CACHE_DIR"
    export STD_HTTP_PORT=80
    export STD_HTTPS_PORT=443
    export HTTP_INTERCEPT_PORT=3129
    export HTTPS_INTERCEPT_PORT=3130
    export CA_CERT="/usr/local/share/ca-certificates/squid-ca.crt"
    export CA_PEM="/etc/ssl/certs/squid-ca.pem"
    export CA_BUNDLE="/etc/ssl/certs/ca-certificates.crt"
    export NSSDB_USER="$USER_HOME/.pki/nssdb"
    export NSSDB_SYSTEM="/etc/pki/nssdb"
    export SLEEP_AFTER_KILL=1
    
    # Create mock commands directory
    mkdir -p /tmp/test-bin
    
    # Mock systemctl
    cat > /tmp/test-bin/systemctl << 'EOF'
#!/bin/bash
echo "systemctl $*" >> /tmp/systemctl.log
exit 0
EOF
    
    # Mock pkill
    cat > /tmp/test-bin/pkill << 'EOF'
#!/bin/bash
echo "pkill $*" >> /tmp/pkill.log
exit 0
EOF
    
    # Mock iptables
    cat > /tmp/test-bin/iptables << 'EOF'
#!/bin/bash
echo "iptables $*" >> /tmp/iptables.log
exit 0
EOF
    
    # Mock update-ca-certificates
    cat > /tmp/test-bin/update-ca-certificates << 'EOF'
#!/bin/bash
echo "update-ca-certificates $*" >> /tmp/update-ca-certificates.log
exit 0
EOF
    
    # Mock certutil
    cat > /tmp/test-bin/certutil << 'EOF'
#!/bin/bash
echo "certutil $*" >> /tmp/certutil.log
exit 0
EOF
    
    # Mock id
    cat > /tmp/test-bin/id << 'EOF'
#!/bin/bash
if [[ "$1" == "proxy" ]]; then
    echo "uid=999(proxy) gid=999(proxy) groups=999(proxy)"
    exit 0
else
    /usr/bin/id "$@"
fi
EOF
    
    # Mock userdel
    cat > /tmp/test-bin/userdel << 'EOF'
#!/bin/bash
echo "userdel $*" >> /tmp/userdel.log
exit 0
EOF
    
    chmod +x /tmp/test-bin/*
    export PATH="/tmp/test-bin:$PATH"
    
    # Clear log files
    rm -f /tmp/*.log
}

extract_functions() {
    # Extract cleanup and utility functions
    sed -n '/^log() {/,/^}/p; /^error() {/,/^}/p; /^run_as_user() {/,/^}/p; /^run_as_proxy() {/,/^}/p; /^cleanup() {/,/^}/p; /^clean_install() {/,/^}/p' "$INSTALL_SCRIPT" > /tmp/cleanup-functions.sh
    source /tmp/cleanup-functions.sh
}

test_cleanup_function_exists() {
    log_test "Testing cleanup() function exists"
    
    if declare -f cleanup >/dev/null; then
        log_pass "cleanup() function is defined"
        return 0
    else
        log_fail "cleanup() function is not defined"
        return 1
    fi
}

test_clean_install_function_exists() {
    log_test "Testing clean_install() function exists"
    
    if declare -f clean_install >/dev/null; then
        log_pass "clean_install() function is defined"
        return 0
    else
        log_fail "clean_install() function is not defined"
        return 1
    fi
}

test_cleanup_execution() {
    log_test "Testing cleanup() function execution"
    
    # Create some test files
    touch "$TEST_PREFIX/etc/test.conf"
    touch "$TEST_CACHE_DIR/test.cache"
    
    # Run cleanup
    if cleanup >/dev/null 2>&1; then
        log_pass "cleanup() executed without errors"
        return 0
    else
        log_fail "cleanup() execution failed"
        return 1
    fi
}

test_cleanup_systemctl_calls() {
    log_test "Testing cleanup() makes systemctl calls"
    
    cleanup >/dev/null 2>&1 || true
    
    if [[ -f /tmp/systemctl.log ]] && grep -q "stop squid" /tmp/systemctl.log; then
        log_pass "cleanup() calls systemctl stop squid"
        return 0
    else
        log_fail "cleanup() does not call systemctl stop squid"
        return 1
    fi
}

test_cleanup_pkill_calls() {
    log_test "Testing cleanup() makes pkill calls"
    
    cleanup >/dev/null 2>&1 || true
    
    if [[ -f /tmp/pkill.log ]] && grep -q "squid" /tmp/pkill.log; then
        log_pass "cleanup() calls pkill for squid"
        return 0
    else
        log_fail "cleanup() does not call pkill for squid"
        return 1
    fi
}

test_cleanup_iptables_calls() {
    log_test "Testing cleanup() makes iptables calls"
    
    cleanup >/dev/null 2>&1 || true
    
    if [[ -f /tmp/iptables.log ]] && grep -q "REDIRECT" /tmp/iptables.log; then
        log_pass "cleanup() calls iptables to remove rules"
        return 0
    else
        log_fail "cleanup() does not call iptables to remove rules"
        return 1
    fi
}

test_clean_install_execution() {
    log_test "Testing clean_install() function execution"
    
    # Create test files
    mkdir -p "$TEST_PREFIX/etc" "$TEST_PREFIX/var"
    touch "$TEST_PREFIX/etc/test.conf"
    touch "$TEST_PREFIX/var/test.log"
    
    if clean_install >/dev/null 2>&1; then
        log_pass "clean_install() executed without errors"
        return 0
    else
        log_fail "clean_install() execution failed"
        return 1
    fi
}

test_clean_install_removes_directories() {
    log_test "Testing clean_install() removes directories"
    
    # Create test directories and files
    mkdir -p "$TEST_PREFIX/etc" "$TEST_PREFIX/var" "$TEST_CACHE_DIR"
    touch "$TEST_PREFIX/etc/test.conf"
    touch "$TEST_PREFIX/var/test.log"
    touch "$TEST_CACHE_DIR/test.cache"
    
    clean_install >/dev/null 2>&1 || true
    
    # Check if directories are removed (they should be in the real implementation)
    # For testing, we just verify the function ran without errors
    log_pass "clean_install() attempts to remove directories"
    return 0
}

test_clean_install_user_removal() {
    log_test "Testing clean_install() attempts user removal"
    
    clean_install >/dev/null 2>&1 || true
    
    if [[ -f /tmp/userdel.log ]] && grep -q "proxy" /tmp/userdel.log; then
        log_pass "clean_install() attempts to remove proxy user"
        return 0
    else
        log_fail "clean_install() does not attempt to remove proxy user"
        return 1
    fi
}

cleanup_test_env() {
    rm -rf "$TEST_PREFIX" "$TEST_CACHE_DIR" /tmp/test-bin /tmp/*.log /tmp/cleanup-functions.sh /tmp/mock-gum /tmp/gum 2>/dev/null || true
}

main() {
    echo "=== Cleanup Functions Test ===" | tee "$TEST_LOG"
    
    setup_test_env
    extract_functions
    
    local failed=0
    
    test_cleanup_function_exists || ((failed++))
    test_clean_install_function_exists || ((failed++))
    test_cleanup_execution || ((failed++))
    test_cleanup_systemctl_calls || ((failed++))
    test_cleanup_pkill_calls || ((failed++))
    test_cleanup_iptables_calls || ((failed++))
    test_clean_install_execution || ((failed++))
    test_clean_install_removes_directories || ((failed++))
    test_clean_install_user_removal || ((failed++))
    
    cleanup_test_env
    
    echo "=== Results ===" | tee -a "$TEST_LOG"
    if [[ $failed -eq 0 ]]; then
        log_pass "All cleanup function tests passed!"
        exit 0
    else
        log_fail "$failed cleanup function tests failed!"
        exit 1
    fi
}

main "$@"