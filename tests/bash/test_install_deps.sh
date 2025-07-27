#!/bin/bash

# Test install_deps function from install-squid.sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/../../scripts/install-squid.sh"
TEST_LOG="/tmp/squid-deps-test-$(date +%s).log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_test() { echo -e "${BLUE}[TEST]${NC} $*" | tee -a "$TEST_LOG"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $*" | tee -a "$TEST_LOG"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $*" | tee -a "$TEST_LOG"; }

setup_test_env() {
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
    
    # Create mock commands directory
    mkdir -p /tmp/test-bin
    
    # Mock apt-get
    cat > /tmp/test-bin/apt-get << 'EOF'
#!/bin/bash
echo "apt-get $*" >> /tmp/apt-get.log
case "$1" in
    update) exit 0 ;;
    install) exit 0 ;;
    *) exit 0 ;;
esac
EOF
    
    # Mock useradd
    cat > /tmp/test-bin/useradd << 'EOF'
#!/bin/bash
echo "useradd $*" >> /tmp/useradd.log
exit 0
EOF
    
    # Mock id
    cat > /tmp/test-bin/id << 'EOF'
#!/bin/bash
if [[ "$1" == "proxy" ]]; then
    # Simulate proxy user doesn't exist initially
    if [[ -f /tmp/proxy-user-exists ]]; then
        echo "uid=999(proxy) gid=999(proxy) groups=999(proxy)"
        exit 0
    else
        exit 1
    fi
else
    /usr/bin/id "$@"
fi
EOF
    
    chmod +x /tmp/test-bin/*
    export PATH="/tmp/test-bin:$PATH"
    
    # Clear log files
    rm -f /tmp/*.log /tmp/proxy-user-exists
}

extract_functions() {
    # Extract install_deps and utility functions
    sed -n '/^log() {/,/^}/p; /^error() {/,/^}/p; /^install_deps() {/,/^}/p' "$INSTALL_SCRIPT" > /tmp/deps-functions.sh
    source /tmp/deps-functions.sh
}

test_install_deps_function_exists() {
    log_test "Testing install_deps() function exists"
    
    if declare -f install_deps >/dev/null; then
        log_pass "install_deps() function is defined"
        return 0
    else
        log_fail "install_deps() function is not defined"
        return 1
    fi
}

test_install_deps_execution() {
    log_test "Testing install_deps() function execution"
    
    if install_deps >/dev/null 2>&1; then
        log_pass "install_deps() executed without errors"
        return 0
    else
        log_fail "install_deps() execution failed"
        return 1
    fi
}

test_apt_update_called() {
    log_test "Testing install_deps() calls apt-get update"
    
    install_deps >/dev/null 2>&1 || true
    
    if [[ -f /tmp/apt-get.log ]] && grep -q "update" /tmp/apt-get.log; then
        log_pass "install_deps() calls apt-get update"
        return 0
    else
        log_fail "install_deps() does not call apt-get update"
        return 1
    fi
}

test_apt_install_called() {
    log_test "Testing install_deps() calls apt-get install"
    
    install_deps >/dev/null 2>&1 || true
    
    if [[ -f /tmp/apt-get.log ]] && grep -q "install" /tmp/apt-get.log; then
        log_pass "install_deps() calls apt-get install"
        return 0
    else
        log_fail "install_deps() does not call apt-get install"
        return 1
    fi
}

test_proxy_user_creation() {
    log_test "Testing install_deps() creates proxy user when needed"
    
    # Ensure proxy user doesn't exist initially
    rm -f /tmp/proxy-user-exists
    
    install_deps >/dev/null 2>&1 || true
    
    if [[ -f /tmp/useradd.log ]] && grep -q "proxy" /tmp/useradd.log; then
        log_pass "install_deps() attempts to create proxy user"
        return 0
    else
        log_fail "install_deps() does not attempt to create proxy user"
        return 1
    fi
}

test_proxy_user_exists_check() {
    log_test "Testing install_deps() checks if proxy user exists"
    
    # Simulate proxy user exists
    touch /tmp/proxy-user-exists
    rm -f /tmp/useradd.log
    
    install_deps >/dev/null 2>&1 || true
    
    # Should not try to create user if it exists
    if [[ ! -f /tmp/useradd.log ]] || ! grep -q "proxy" /tmp/useradd.log; then
        log_pass "install_deps() skips user creation when user exists"
        return 0
    else
        log_fail "install_deps() tries to create user even when it exists"
        return 1
    fi
}

test_required_packages() {
    log_test "Testing install_deps() installs required packages"
    
    install_deps >/dev/null 2>&1 || true
    
    local required_packages=(
        "build-essential"
        "autoconf"
        "automake"
        "libtool"
        "openssl"
        "libssl-dev"
        "wget"
    )
    
    local found_packages=0
    for package in "${required_packages[@]}"; do
        if [[ -f /tmp/apt-get.log ]] && grep -q "$package" /tmp/apt-get.log; then
            ((found_packages++))
        fi
    done
    
    if [[ $found_packages -ge 3 ]]; then
        log_pass "install_deps() installs required packages"
        return 0
    else
        log_fail "install_deps() does not install enough required packages"
        return 1
    fi
}

cleanup_test_env() {
    rm -rf /tmp/test-bin /tmp/*.log /tmp/deps-functions.sh /tmp/mock-gum /tmp/gum /tmp/proxy-user-exists 2>/dev/null || true
}

main() {
    echo "=== Install Dependencies Test ===" | tee "$TEST_LOG"
    
    setup_test_env
    extract_functions
    
    local failed=0
    
    test_install_deps_function_exists || ((failed++))
    test_install_deps_execution || ((failed++))
    test_apt_update_called || ((failed++))
    test_apt_install_called || ((failed++))
    test_proxy_user_creation || ((failed++))
    test_proxy_user_exists_check || ((failed++))
    test_required_packages || ((failed++))
    
    cleanup_test_env
    
    echo "=== Results ===" | tee -a "$TEST_LOG"
    if [[ $failed -eq 0 ]]; then
        log_pass "All install_deps function tests passed!"
        exit 0
    else
        log_fail "$failed install_deps function tests failed!"
        exit 1
    fi
}

main "$@"