#!/bin/bash

# Test build_squid function from install-squid.sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/../../scripts/install-squid.sh"
TEST_LOG="/tmp/squid-build-test-$(date +%s).log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_test() { echo -e "${BLUE}[TEST]${NC} $*" | tee -a "$TEST_LOG"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $*" | tee -a "$TEST_LOG"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $*" | tee -a "$TEST_LOG"; }

setup_test_env() {
    export TEST_PREFIX="/tmp/test-squid-build"
    export VER="7.1"
    export PREFIX="$TEST_PREFIX"
    export SQUID_URL="https://github.com/squid-cache/squid/archive/refs/tags/SQUID_$(echo $VER | sed 's/\./_/g').tar.gz"
    
    mkdir -p "$TEST_PREFIX/sbin"
    
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
    
    # Mock wget
    cat > /tmp/test-bin/wget << 'EOF'
#!/bin/bash
echo "wget $*" >> /tmp/wget.log
# Create a fake tarball
if [[ "$*" == *"-qO"* ]]; then
    output_file=$(echo "$*" | grep -o '\S*\.tar\.gz')
    mkdir -p "$(dirname "$output_file")"
    echo "fake tarball" > "$output_file"
fi
exit 0
EOF
    
    # Mock tar
    cat > /tmp/test-bin/tar << 'EOF'
#!/bin/bash
echo "tar $*" >> /tmp/tar.log
# Create fake extracted directory
if [[ "$*" == *"-xf"* ]]; then
    extract_dir=$(echo "$*" | grep -o '\-C \S*' | cut -d' ' -f2)
    if [[ -n "$extract_dir" ]]; then
        mkdir -p "$extract_dir/squid-SQUID_7_1"
        echo '#!/bin/bash
echo "configure $*" >> /tmp/configure.log
exit 0' > "$extract_dir/squid-SQUID_7_1/configure"
        chmod +x "$extract_dir/squid-SQUID_7_1/configure"
        echo '#!/bin/bash
echo "bootstrap $*" >> /tmp/bootstrap.log
exit 0' > "$extract_dir/squid-SQUID_7_1/bootstrap.sh"
        chmod +x "$extract_dir/squid-SQUID_7_1/bootstrap.sh"
    fi
fi
exit 0
EOF
    
    # Mock make
    cat > /tmp/test-bin/make << 'EOF'
#!/bin/bash
echo "make $*" >> /tmp/make.log
if [[ "$*" == "install" ]]; then
    # Create fake squid binary
    mkdir -p "$PREFIX/sbin"
    echo '#!/bin/bash
echo "Squid Cache: Version 7.1"' > "$PREFIX/sbin/squid"
    chmod +x "$PREFIX/sbin/squid"
fi
exit 0
EOF
    
    # Mock chown
    cat > /tmp/test-bin/chown << 'EOF'
#!/bin/bash
echo "chown $*" >> /tmp/chown.log
exit 0
EOF
    
    # Mock nproc
    cat > /tmp/test-bin/nproc << 'EOF'
#!/bin/bash
echo "4"
EOF
    
    chmod +x /tmp/test-bin/*
    export PATH="/tmp/test-bin:$PATH"
    
    # Clear log files
    rm -f /tmp/*.log
}

extract_functions() {
    # Extract build_squid and utility functions
    sed -n '/^log() {/,/^}/p; /^error() {/,/^}/p; /^build_squid() {/,/^}/p' "$INSTALL_SCRIPT" > /tmp/build-functions.sh
    source /tmp/build-functions.sh
}

test_build_squid_function_exists() {
    log_test "Testing build_squid() function exists"
    
    if declare -f build_squid >/dev/null; then
        log_pass "build_squid() function is defined"
        return 0
    else
        log_fail "build_squid() function is not defined"
        return 1
    fi
}

test_build_squid_checks_existing() {
    log_test "Testing build_squid() checks for existing installation"
    
    # Create fake existing squid binary
    mkdir -p "$PREFIX/sbin"
    echo '#!/bin/bash
echo "Squid Cache: Version 7.1"' > "$PREFIX/sbin/squid"
    chmod +x "$PREFIX/sbin/squid"
    
    local output
    output=$(build_squid 2>&1)
    
    if [[ "$output" == *"already built"* ]]; then
        log_pass "build_squid() detects existing installation"
        return 0
    else
        log_fail "build_squid() does not detect existing installation"
        return 1
    fi
}

test_build_squid_downloads() {
    log_test "Testing build_squid() downloads source"
    
    # Remove existing binary to force build
    rm -f "$PREFIX/sbin/squid"
    
    build_squid >/dev/null 2>&1 || true
    
    if [[ -f /tmp/wget.log ]] && grep -q "tar.gz" /tmp/wget.log; then
        log_pass "build_squid() downloads source tarball"
        return 0
    else
        log_fail "build_squid() does not download source tarball"
        return 1
    fi
}

test_build_squid_extracts() {
    log_test "Testing build_squid() extracts source"
    
    build_squid >/dev/null 2>&1 || true
    
    if [[ -f /tmp/tar.log ]] && grep -q "\-xf" /tmp/tar.log; then
        log_pass "build_squid() extracts source tarball"
        return 0
    else
        log_fail "build_squid() does not extract source tarball"
        return 1
    fi
}

test_build_squid_configures() {
    log_test "Testing build_squid() runs configure"
    
    build_squid >/dev/null 2>&1 || true
    
    if [[ -f /tmp/configure.log ]]; then
        log_pass "build_squid() runs configure script"
        return 0
    else
        log_fail "build_squid() does not run configure script"
        return 1
    fi
}

test_build_squid_makes() {
    log_test "Testing build_squid() runs make"
    
    build_squid >/dev/null 2>&1 || true
    
    if [[ -f /tmp/make.log ]] && grep -q "\-j" /tmp/make.log; then
        log_pass "build_squid() runs make with parallel jobs"
        return 0
    else
        log_fail "build_squid() does not run make with parallel jobs"
        return 1
    fi
}

test_build_squid_installs() {
    log_test "Testing build_squid() runs make install"
    
    build_squid >/dev/null 2>&1 || true
    
    if [[ -f /tmp/make.log ]] && grep -q "install" /tmp/make.log; then
        log_pass "build_squid() runs make install"
        return 0
    else
        log_fail "build_squid() does not run make install"
        return 1
    fi
}

test_build_squid_sets_ownership() {
    log_test "Testing build_squid() sets ownership"
    
    build_squid >/dev/null 2>&1 || true
    
    if [[ -f /tmp/chown.log ]] && grep -q "proxy:proxy" /tmp/chown.log; then
        log_pass "build_squid() sets ownership to proxy user"
        return 0
    else
        log_fail "build_squid() does not set ownership to proxy user"
        return 1
    fi
}

test_build_squid_execution() {
    log_test "Testing build_squid() function execution"
    
    # Remove existing binary to force build
    rm -f "$PREFIX/sbin/squid"
    
    if build_squid >/dev/null 2>&1; then
        log_pass "build_squid() executed without errors"
        return 0
    else
        log_fail "build_squid() execution failed"
        return 1
    fi
}

cleanup_test_env() {
    rm -rf "$TEST_PREFIX" /tmp/test-bin /tmp/*.log /tmp/build-functions.sh /tmp/mock-gum /tmp/gum 2>/dev/null || true
}

main() {
    echo "=== Build Squid Function Test ===" | tee "$TEST_LOG"
    
    setup_test_env
    extract_functions
    
    local failed=0
    
    test_build_squid_function_exists || ((failed++))
    test_build_squid_checks_existing || ((failed++))
    test_build_squid_downloads || ((failed++))
    test_build_squid_extracts || ((failed++))
    test_build_squid_configures || ((failed++))
    test_build_squid_makes || ((failed++))
    test_build_squid_installs || ((failed++))
    test_build_squid_sets_ownership || ((failed++))
    test_build_squid_execution || ((failed++))
    
    cleanup_test_env
    
    echo "=== Results ===" | tee -a "$TEST_LOG"
    if [[ $failed -eq 0 ]]; then
        log_pass "All build_squid function tests passed!"
        exit 0
    else
        log_fail "$failed build_squid function tests failed!"
        exit 1
    fi
}

main "$@"