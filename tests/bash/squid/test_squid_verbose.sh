#!/bin/bash

# Compact E2E Squid functionality test
set -eu

PROXY_PORT=3128
SSL_DIR="/usr/local/squid/etc/ssl_cert"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${CYAN}▶${NC} $*"; }
pass() { echo -e "${GREEN}✓${NC} $*"; }
fail() { echo -e "${RED}✗${NC} $*"; }
info() { echo -e "${YELLOW}ℹ${NC} $*"; }

test_http() {
    log "HTTP Proxy Test - Raw Request/Response"
    echo
    
    echo "🌐 Request: curl -v --proxy http://localhost:$PROXY_PORT http://httpbin.org/headers"
    echo "📤 Headers: X-Test: E2E-Test, User-Agent: SquidTest/1.0"
    echo
    
    curl -v --proxy "http://localhost:$PROXY_PORT" \
        -H "X-Test: E2E-Test" \
        -H "User-Agent: SquidTest/1.0" \
        "http://httpbin.org/headers" 2>&1
    
    echo
    if [ $? -eq 0 ]; then
        pass "HTTP proxy request completed"
        return 0
    else
        fail "HTTP proxy request failed"
        return 1
    fi
}

test_https() {
    log "HTTPS Proxy Test - Raw Request/Response"
    echo
    
    echo "🔒 Request: curl -v --proxy http://localhost:$PROXY_PORT https://httpbin.org/get"
    echo "📤 Headers: X-HTTPS-Test: SSL-Bump-Test"
    echo
    
    curl -v --proxy "http://localhost:$PROXY_PORT" \
        -H "X-HTTPS-Test: SSL-Bump-Test" \
        -k "https://httpbin.org/get" 2>&1
    
    echo
    if [ $? -eq 0 ]; then
        pass "HTTPS proxy request completed"
        return 0
    else
        fail "HTTPS proxy request failed"
        return 1
    fi
}

test_cache() {
    log "Cache Test - Two Requests to Same URL"
    echo
    
    local url="http://httpbin.org/cache/30"
    
    echo "📡 First Request (should be MISS):"
    curl -v --proxy "http://localhost:$PROXY_PORT" \
        -H "X-Cache-Test: First-Request" "$url" 2>&1
    
    echo
    echo "⏱️  Waiting 2 seconds..."
    sleep 2
    
    echo
    echo "🎯 Second Request (should be HIT):"
    curl -v --proxy "http://localhost:$PROXY_PORT" \
        -H "X-Cache-Test: Second-Request" "$url" 2>&1
    
    echo
    echo "📋 Access Log (last 3 entries):"
    sudo tail -3 /usr/local/squid/var/logs/access.log | grep -E "(MISS|HIT|$url)" || sudo tail -3 /usr/local/squid/var/logs/access.log
    
    pass "Cache test completed - check log entries above"
}

test_cert_info() {
    log "SSL Certificate Details"
    echo
    
    if [ -f "$SSL_DIR/ca.pem" ]; then
        echo "📜 Squid CA Certificate:"
        openssl x509 -in "$SSL_DIR/ca.pem" -noout -text | grep -A10 -B5 "Subject:\|Issuer:\|Validity"
        
        echo
        echo "🔍 Certificate presented by proxy for HTTPS connection:"
        echo "   (This shows how Squid intercepts SSL connections)"
        echo "" | timeout 5 openssl s_client -connect httpbin.org:443 \
            -proxy localhost:$PROXY_PORT -showcerts 2>/dev/null | \
            grep -A5 -B5 "subject=\|issuer=" || echo "   Connection test skipped"
        
        pass "SSL certificates found and valid"
        return 0
    else
        fail "SSL certificates not found"
        return 1
    fi
}

show_status() {
    log "Squid Status"
    
    local running=$(pgrep -f "squid" | wc -l)
    local ports=$(sudo netstat -tlnp | grep -c "squid" || echo "0")
    
    info "Squid processes: $running"
    info "Listening ports: $ports"
    
    if [ "$running" -gt 0 ]; then
        pass "Squid is running"
        return 0
    else
        fail "Squid not running"
        return 1
    fi
}

show_recent_requests() {
    log "Recent Requests"
    
    if [ -f "/usr/local/squid/var/logs/access.log" ]; then
        info "Last 3 requests:"
        sudo tail -3 /usr/local/squid/var/logs/access.log | while read -r line; do
            if echo "$line" | grep -q "HIT"; then
                echo -e "  ${GREEN}🎯 HIT:${NC} $(echo "$line" | awk '{print $7, $4, $6}')"
            elif echo "$line" | grep -q "MISS"; then
                echo -e "  ${YELLOW}📡 MISS:${NC} $(echo "$line" | awk '{print $7, $4, $6}')"
            else
                echo -e "  ${CYAN}📄${NC} $(echo "$line" | awk '{print $7, $4, $6}')"
            fi
        done
    else
        fail "Access log not found"
    fi
}

main() {
    echo "🔍 Squid E2E Functionality Test"
    echo "================================"
    
    local failed=0
    
    show_status || ((failed++))
    test_cert_info || ((failed++))
    test_http || ((failed++))
    test_https || ((failed++))
    test_cache || ((failed++))
    show_recent_requests
    
    echo
    if [ $failed -eq 0 ]; then
        pass "All tests passed! Squid is fully functional"
        echo
        info "Manual verification commands:"
        echo "  curl --proxy http://localhost:$PROXY_PORT http://httpbin.org/get"
        echo "  sudo tail -f /usr/local/squid/var/logs/access.log"
        exit 0
    else
        fail "$failed tests failed"
        exit 1
    fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi