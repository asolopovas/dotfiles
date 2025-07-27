#!/bin/bash

# Comprehensive Squid installation and functionality test
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/../../scripts/install-squid.sh"
TEST_LOG="/tmp/squid-functional-test-$(date +%s).log"

# Test configuration
TEST_PREFIX="/tmp/test-squid-install"
TEST_CACHE_DIR="/tmp/test-squid-cache"
TEST_USER="squidtest"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_test() { echo -e "${BLUE}[TEST]${NC} $*" | tee -a "$TEST_LOG"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $*" | tee -a "$TEST_LOG"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $*" | tee -a "$TEST_LOG"; }
log_info() { echo -e "${YELLOW}[INFO]${NC} $*" | tee -a "$TEST_LOG"; }

# Check if running as root/sudo
check_prerequisites() {
    log_test "Checking prerequisites"
    
    if [[ $EUID -ne 0 ]]; then
        log_fail "This test must be run with sudo privileges"
        echo "Usage: sudo $0"
        exit 1
    fi
    
    if [[ -z "${SUDO_USER:-}" ]]; then
        log_fail "Must be run with sudo, not as root directly"
        echo "Usage: sudo $0"
        exit 1
    fi
    
    # Check required commands
    local required_commands=("curl" "wget" "make" "gcc" "openssl")
    local missing=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_fail "Missing required commands: ${missing[*]}"
        return 1
    fi
    
    log_pass "Prerequisites check passed"
    return 0
}

# Test basic connectivity before installation
test_baseline_connectivity() {
    log_test "Testing baseline internet connectivity"
    
    local test_sites=("https://google.com" "https://github.com" "https://httpbin.org/get")
    local failed=0
    
    for site in "${test_sites[@]}"; do
        if ! curl -s --max-time 10 "$site" >/dev/null 2>&1; then
            log_fail "Cannot reach $site"
            ((failed++))
        fi
    done
    
    if [[ $failed -eq 0 ]]; then
        log_pass "Baseline connectivity working"
        return 0
    else
        log_fail "Baseline connectivity issues ($failed sites unreachable)"
        return 1
    fi
}

# Clean any existing squid installation
cleanup_existing() {
    log_test "Cleaning existing squid installation"
    
    # Stop any running squid processes
    systemctl stop squid 2>/dev/null || true
    pkill -f squid 2>/dev/null || true
    
    # Remove iptables rules
    iptables -t nat -F OUTPUT 2>/dev/null || true
    
    # Remove directories
    rm -rf /usr/local/squid /etc/systemd/system/squid.service
    rm -rf "$TEST_PREFIX" "$TEST_CACHE_DIR"
    
    # Remove certificates
    rm -f /usr/local/share/ca-certificates/squid-ca.crt
    rm -f /etc/ssl/certs/squid-ca.pem
    update-ca-certificates --fresh >/dev/null 2>&1 || true
    
    # Remove proxy user
    if id proxy >/dev/null 2>&1; then
        pkill -9 -u proxy 2>/dev/null || true
        userdel -rf proxy 2>/dev/null || true
    fi
    
    systemctl daemon-reload
    
    log_pass "Cleanup completed"
}

# Test squid installation
test_squid_installation() {
    log_test "Testing squid installation"
    
    log_info "Starting squid installation (this may take several minutes)..."
    
    # Run the install script with timeout
    if timeout 1800 "$INSTALL_SCRIPT" >>"$TEST_LOG" 2>&1; then
        log_pass "Squid installation completed successfully"
        return 0
    else
        local exit_code=$?
        log_fail "Squid installation failed (exit code: $exit_code)"
        echo "Last 20 lines of installation log:"
        tail -20 "$TEST_LOG" | grep -v "^$"
        return 1
    fi
}

# Test squid binary and version
test_squid_binary() {
    log_test "Testing squid binary"
    
    local squid_binary="/usr/local/squid/sbin/squid"
    
    if [[ ! -x "$squid_binary" ]]; then
        log_fail "Squid binary not found or not executable"
        return 1
    fi
    
    local version
    if version=$("$squid_binary" -v 2>/dev/null | head -1); then
        log_pass "Squid binary working: $version"
        return 0
    else
        log_fail "Squid binary not working"
        return 1
    fi
}

# Test squid configuration
test_squid_config() {
    log_test "Testing squid configuration"
    
    local config_file="/usr/local/squid/etc/squid.conf"
    
    if [[ ! -f "$config_file" ]]; then
        log_fail "Squid config file not found"
        return 1
    fi
    
    # Test config syntax
    if sudo -u proxy /usr/local/squid/sbin/squid -k parse -f "$config_file" >/dev/null 2>&1; then
        log_pass "Squid configuration syntax is valid"
        return 0
    else
        log_fail "Squid configuration has syntax errors"
        return 1
    fi
}

# Test squid service
test_squid_service() {
    log_test "Testing squid service"
    
    # Check if squid is running
    if ! pgrep -f "/usr/local/squid/sbin/squid" >/dev/null; then
        log_fail "Squid process not running"
        return 1
    fi
    
    # Check if ports are listening
    local proxy_port=3128
    local http_intercept=3129
    local https_intercept=3130
    
    local listening_ports=()
    if netstat -ln 2>/dev/null | grep -q ":$proxy_port.*LISTEN"; then
        listening_ports+=("$proxy_port")
    fi
    if netstat -ln 2>/dev/null | grep -q ":$http_intercept.*LISTEN"; then
        listening_ports+=("$http_intercept")
    fi
    if netstat -ln 2>/dev/null | grep -q ":$https_intercept.*LISTEN"; then
        listening_ports+=("$https_intercept")
    fi
    
    if [[ ${#listening_ports[@]} -ge 1 ]]; then
        log_pass "Squid service running, listening on ports: ${listening_ports[*]}"
        return 0
    else
        log_fail "Squid not listening on expected ports"
        return 1
    fi
}

# Test SSL certificates
test_ssl_certificates() {
    log_test "Testing SSL certificates"
    
    local ssl_dir="/usr/local/squid/etc/ssl_cert"
    local ca_cert="$ssl_dir/ca.crt"
    local server_cert="$ssl_dir/squid-self-signed.crt"
    
    if [[ ! -f "$ca_cert" ]] || [[ ! -f "$server_cert" ]]; then
        log_fail "SSL certificates not found"
        return 1
    fi
    
    # Test certificate validity
    if openssl x509 -in "$ca_cert" -noout -text >/dev/null 2>&1 &&
       openssl x509 -in "$server_cert" -noout -text >/dev/null 2>&1; then
        
        local ca_expires=$(openssl x509 -in "$ca_cert" -noout -enddate | cut -d= -f2)
        log_pass "SSL certificates are valid (CA expires: $ca_expires)"
        return 0
    else
        log_fail "SSL certificates are invalid"
        return 1
    fi
}

# Test proxy functionality
test_proxy_functionality() {
    log_test "Testing proxy functionality"
    
    local proxy_port=3128
    local test_url="http://httpbin.org/get"
    
    # Test HTTP proxy
    local response
    if response=$(curl -s --max-time 15 --proxy "http://localhost:$proxy_port" "$test_url" 2>/dev/null); then
        if echo "$response" | grep -q '"url".*httpbin'; then
            log_pass "HTTP proxy functionality working"
        else
            log_fail "HTTP proxy returned unexpected response"
            return 1
        fi
    else
        log_fail "HTTP proxy not responding"
        return 1
    fi
    
    # Test HTTPS proxy
    local https_url="https://httpbin.org/get"
    if response=$(curl -s --max-time 15 --proxy "http://localhost:$proxy_port" -k "$https_url" 2>/dev/null); then
        if echo "$response" | grep -q '"url".*httpbin'; then
            log_pass "HTTPS proxy functionality working"
        else
            log_fail "HTTPS proxy returned unexpected response"
            return 1
        fi
    else
        log_fail "HTTPS proxy not responding"
        return 1
    fi
    
    return 0
}

# Test transparent proxy (iptables rules)
test_transparent_proxy() {
    log_test "Testing transparent proxy setup"
    
    # Check if iptables rules exist
    local http_rule_count=$(iptables -t nat -L OUTPUT | grep -c "REDIRECT.*tcp dpt:80" || true)
    local https_rule_count=$(iptables -t nat -L OUTPUT | grep -c "REDIRECT.*tcp dpt:443" || true)
    
    if [[ $http_rule_count -gt 0 ]] && [[ $https_rule_count -gt 0 ]]; then
        log_pass "Transparent proxy iptables rules configured"
        return 0
    else
        log_fail "Transparent proxy iptables rules missing"
        return 1
    fi
}

# Test cache functionality
test_cache_functionality() {
    log_test "Testing cache functionality"
    
    local cache_dir="/mnt/d/.cache/web"
    
    # Check if cache directory exists and has proper permissions
    if [[ -d "$cache_dir" ]]; then
        local owner=$(stat -c "%U" "$cache_dir" 2>/dev/null || echo "unknown")
        if [[ "$owner" == "proxy" ]]; then
            log_pass "Cache directory configured correctly (owner: $owner)"
        else
            log_fail "Cache directory has wrong ownership (owner: $owner, expected: proxy)"
            return 1
        fi
    else
        log_fail "Cache directory not found: $cache_dir"
        return 1
    fi
    
    # Check if squid can write to cache
    local swap_state="$cache_dir/swap.state"
    if [[ -f "$swap_state" ]]; then
        log_pass "Cache appears to be functional"
        return 0
    else
        log_fail "Cache swap.state file not found"
        return 1
    fi
}

# Test systemd service
test_systemd_service() {
    log_test "Testing systemd service"
    
    local service_file="/etc/systemd/system/squid.service"
    
    if [[ ! -f "$service_file" ]]; then
        log_fail "Systemd service file not found"
        return 1
    fi
    
    # Check if service is enabled
    if systemctl is-enabled squid >/dev/null 2>&1; then
        log_pass "Squid systemd service is enabled"
        return 0
    else
        log_fail "Squid systemd service is not enabled"
        return 1
    fi
}

# Test argument handling
test_argument_handling() {
    log_test "Testing script argument handling"
    
    # Test --clean option (dry run check)
    if grep -q "case.*--clean" "$INSTALL_SCRIPT" &&
       grep -q "clean_install.*exit" "$INSTALL_SCRIPT"; then
        log_pass "Script has --clean argument handling"
    else
        log_fail "Script missing --clean argument handling"
        return 1
    fi
    
    # Test --disable option (dry run check)
    if grep -q "case.*--disable" "$INSTALL_SCRIPT" &&
       grep -q "cleanup.*exit" "$INSTALL_SCRIPT"; then
        log_pass "Script has --disable argument handling"
    else
        log_fail "Script missing --disable argument handling"
        return 1
    fi
    
    return 0
}

# Performance test
test_performance() {
    log_test "Testing proxy performance"
    
    local proxy_port=3128
    local test_url="http://httpbin.org/get"
    
    # Test response time
    local start_time=$(date +%s.%N)
    if curl -s --max-time 10 --proxy "http://localhost:$proxy_port" "$test_url" >/dev/null 2>&1; then
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "N/A")
        
        if [[ "$duration" != "N/A" ]] && (( $(echo "$duration < 5.0" | bc -l 2>/dev/null || echo 0) )); then
            log_pass "Proxy performance acceptable (${duration}s)"
        else
            log_pass "Proxy working (response time: ${duration}s)"
        fi
    else
        log_fail "Proxy performance test failed"
        return 1
    fi
    
    return 0
}

# Main test execution
main() {
    echo "============================================" | tee "$TEST_LOG"
    echo "   Squid Installation Functionality Test" | tee -a "$TEST_LOG"
    echo "============================================" | tee -a "$TEST_LOG"
    echo | tee -a "$TEST_LOG"
    
    local failed=0
    
    # Pre-installation tests
    check_prerequisites || ((failed++))
    test_baseline_connectivity || ((failed++))
    test_argument_handling || ((failed++))
    
    if [[ $failed -gt 0 ]]; then
        log_fail "Pre-installation tests failed. Aborting."
        exit 1
    fi
    
    # Clean and install
    cleanup_existing
    test_squid_installation || ((failed++))
    
    if [[ $failed -gt 0 ]]; then
        log_fail "Installation failed. Aborting further tests."
        exit 1
    fi
    
    # Post-installation functionality tests
    test_squid_binary || ((failed++))
    test_squid_config || ((failed++))
    test_squid_service || ((failed++))
    test_ssl_certificates || ((failed++))
    test_proxy_functionality || ((failed++))
    test_transparent_proxy || ((failed++))
    test_cache_functionality || ((failed++))
    test_systemd_service || ((failed++))
    test_performance || ((failed++))
    
    echo | tee -a "$TEST_LOG"
    echo "============================================" | tee -a "$TEST_LOG"
    echo "                 SUMMARY" | tee -a "$TEST_LOG"
    echo "============================================" | tee -a "$TEST_LOG"
    
    if [[ $failed -eq 0 ]]; then
        log_pass "🎉 ALL FUNCTIONALITY TESTS PASSED!"
        echo | tee -a "$TEST_LOG"
        echo "✅ Squid proxy is fully functional and ready to use" | tee -a "$TEST_LOG"
        echo "📁 Test log: $TEST_LOG" | tee -a "$TEST_LOG"
        exit 0
    else
        log_fail "❌ $failed functionality tests failed"
        echo | tee -a "$TEST_LOG"
        echo "💡 Check the test log for details: $TEST_LOG" | tee -a "$TEST_LOG"
        echo "🔧 Run: sudo $INSTALL_SCRIPT --clean  # to clean up" | tee -a "$TEST_LOG"
        exit 1
    fi
}

# Safety check
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi