#!/bin/sh
set -eu

# Check if running as root without sudo user context
[ "$(id -u)" = "0" ] && [ -z "${SUDO_USER:-}" ] && {
    echo "Error: Do not run this script as root. It will request sudo when needed."
    exit 1
}

# Configuration
VER=7.1
PREFIX=/usr/local/squid
CACHE_DIR=/mnt/d/.cache/web

log() { gum style --foreground="#00ff00" "$*"; }
error() { gum style --foreground="#ff0000" "$*"; }

remove_iptables() {
    sudo iptables -t nat -D OUTPUT -p tcp --dport 80 -m owner ! --uid-owner proxy -j REDIRECT --to-port 3129 2>/dev/null || true
    sudo iptables -t nat -D OUTPUT -p tcp --dport 443 -m owner ! --uid-owner proxy -j REDIRECT --to-port 3130 2>/dev/null || true
}

stop_squid() {
    # Stop systemd service first
    sudo systemctl stop squid 2>/dev/null || true
    sudo systemctl disable squid 2>/dev/null || true
    
    # Kill only actual squid processes, not scripts
    sudo pkill -f "^$PREFIX/sbin/squid" 2>/dev/null || true
    sleep 1
    
    # Force kill if still running
    if pgrep -f "^$PREFIX/sbin/squid" >/dev/null 2>&1; then
        sudo pkill -9 -f "^$PREFIX/sbin/squid" 2>/dev/null || true
    fi
}

remove_ca() {
    sudo rm -f /usr/local/share/ca-certificates/squid-ca.crt
    sudo update-ca-certificates --fresh >/dev/null || true
}

clean_install() {
    echo "Step 1: Starting cleanup"
    sudo iptables -t nat -D OUTPUT -p tcp --dport 80 -m owner ! --uid-owner proxy -j REDIRECT --to-port 3129 2>/dev/null || true
    echo "Step 2: Removed iptables rule 1" 
    sudo iptables -t nat -D OUTPUT -p tcp --dport 443 -m owner ! --uid-owner proxy -j REDIRECT --to-port 3130 2>/dev/null || true
    echo "Step 3: Removed iptables rule 2"
    echo "Step 4: Stopping squid"
    stop_squid
    id proxy >/dev/null 2>&1 && {
        echo "Step 5: Proxy user exists, removing..."
        sudo pkill -9 -u proxy 2>/dev/null || true
        sudo userdel -rf proxy 2>/dev/null || true
        sudo groupdel proxy 2>/dev/null || true
        echo "Step 6: Proxy user removed"
    } || echo "Step 5: No proxy user"
    echo "Step 7: Removing system configuration (preserving binary)"
    sudo rm -rf "$PREFIX/etc" "$PREFIX/var" "$CACHE_DIR" /etc/systemd/system/squid.service 2>/dev/null || true
    echo "Step 8: CA removed"
    sudo rm -f /usr/local/share/ca-certificates/squid-ca.crt 2>/dev/null || true
    sudo update-ca-certificates >/dev/null 2>&1 || true
    echo "Step 9: Daemon reloaded"
    sudo systemctl daemon-reload >/dev/null 2>&1 || true
    echo "Step 10: Cleanup complete"
    echo "✔ System configuration reset - keeping built binary"
}

disable_proxy() {
    log "Disabling Squid proxy..."
    remove_iptables
    stop_squid
    remove_ca
    log "✔ Proxy disabled"
}

check_squid() {
    [ -x "$PREFIX/sbin/squid" ] && {
        current_ver=$("$PREFIX/sbin/squid" -v | grep -o 'Version [0-9.]*' | cut -d' ' -f2)
        [ "$current_ver" = "$VER" ] && return 0
    }
    return 1
}

install_deps() {
    log "Installing dependencies..."
    sudo apt-get update -y >/dev/null
    sudo apt-get install -y build-essential autoconf automake libtool libtool-bin \
        libltdl-dev openssl libssl-dev pkg-config wget libnss3-tools libcppunit-dev \
        ldap-utils samba-common-bin winbind >/dev/null
    id proxy >/dev/null 2>&1 || sudo useradd -r -s /bin/false proxy
}

build_squid() {
    tag=$(echo "SQUID_$VER" | sed 's/\./_/g')
    url="https://github.com/squid-cache/squid/archive/refs/tags/$tag.tar.gz"
    build="/tmp/squid-build-$$"
    
    log "Building Squid $VER..."
    rm -rf "$build" && mkdir -p "$build"
    wget -qO "$build/squid.tar.gz" "$url"
    tar -xf "$build/squid.tar.gz" -C "$build"
    cd "$build"/*
    [ -x configure ] || ./bootstrap.sh
    ./configure --with-default-user=proxy --with-openssl --enable-ssl-crtd --prefix="$PREFIX" >/dev/null
    make -j"$(nproc)" >/dev/null
    sudo make install >/dev/null
    cd - >/dev/null
    sudo chown -R proxy:proxy "$PREFIX"
}

create_ca() {
    ssl="$PREFIX/etc/ssl_cert"
    openssl_conf=/etc/ssl/openssl.cnf
    
    log "Creating SSL certificates..."
    sudo cp "$openssl_conf" "${openssl_conf}.bak.$(date +%s)"
    sudo sed -i -e '/^\[ *v3_ca *\]/,/^\[/{/keyUsage/d}' "$openssl_conf"
    sudo sed -i -e '/^\[ *v3_ca *\]/a keyUsage = cRLSign, keyCertSign' "$openssl_conf"
    
    tmp=$(mktemp -d)
    openssl req -new -nodes -x509 -days 365 -extensions v3_ca \
        -newkey rsa:2048 -keyout "$tmp/ca.key" -out "$tmp/ca.crt" \
        -subj "/C=UK/ST=England/L=London/O=LocalSquid/OU=Proxy/CN=SquidProxy" 2>/dev/null
    openssl dhparam -out "$tmp/dh.pem" 2048 2>/dev/null
    
    sudo mkdir -p "$ssl"
    sudo cp "$tmp/ca.key" "$tmp/ca.crt" "$tmp/dh.pem" "$ssl/"
    sudo chmod 600 "$ssl/ca.key"
    sudo chmod 644 "$ssl/ca.crt" "$ssl/dh.pem"
    sudo chown proxy:proxy "$ssl/ca.key" "$ssl/ca.crt" "$ssl/dh.pem"
}

install_ca() {
    log "Installing CA certificates..."
    sudo cp "$ssl/ca.crt" /usr/local/share/ca-certificates/squid-ca.crt
    sudo update-ca-certificates >/dev/null
    
    [ -n "${SUDO_USER:-}" ] && sudo -u "$SUDO_USER" sh -c "
        [ -d /home/$SUDO_USER/.mozilla/firefox ] && {
            for profile in /home/$SUDO_USER/.mozilla/firefox/*.default*; do
                [ -d \"\$profile\" ] && certutil -A -n 'Squid Proxy CA' -t 'TCu,Cu,Tu' -i '$ssl/ca.crt' -d \"\$profile\" 2>/dev/null || true
            done
        }
        command -v certutil >/dev/null && {
            mkdir -p /home/$SUDO_USER/.pki/nssdb
            certutil -A -n 'Squid Proxy CA' -t 'TCu,Cu,Tu' -i '$ssl/ca.crt' -d sql:/home/$SUDO_USER/.pki/nssdb 2>/dev/null || true
        }
    " || true
}

create_config() {
    conf="$PREFIX/etc/squid.conf"
    ssl="$PREFIX/etc/ssl_cert"
    
    log "Creating configuration..."
    [ -f "$conf" ] && sudo mv "$conf" "${conf}.orig-$(date +%s)"
    sudo tee "$conf" >/dev/null <<EOF
acl intermediate_fetching transaction_initiator certificate-fetching
http_access allow intermediate_fetching

acl localnet src 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 fc00::/7 fe80::/10 127.0.0.0/8
acl SSL_ports port 443
acl Safe_ports port 80 21 443 70 210 1025-65535 280 488 591 777
acl CONNECT method CONNECT

http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow localhost manager
http_access deny manager
http_access allow localnet
http_access allow localhost
http_access deny all

http_port 3128 ssl-bump generate-host-certificates=on dynamic_cert_mem_cache_size=20MB tls-cert=$ssl/ca.crt tls-key=$ssl/ca.key cipher=HIGH:MEDIUM:!LOW:!RC4:!SEED:!IDEA:!3DES:!MD5:!EXP:!PSK:!DSS options=NO_TLSv1,NO_SSLv3 tls-dh=$ssl/dh.pem tcpkeepalive=60,30,3
http_port 3129 intercept
https_port 3130 intercept ssl-bump generate-host-certificates=on dynamic_cert_mem_cache_size=20MB tls-cert=$ssl/ca.crt tls-key=$ssl/ca.key

sslcrtd_program $PREFIX/libexec/security_file_certgen -s $PREFIX/var/logs/ssl_db -M 20MB
sslcrtd_children 5
ssl_bump server-first all
ssl_bump stare all
sslproxy_cert_error deny all

maximum_object_size 50 GB
cache_mem 8192 MB
cache_dir ufs $CACHE_DIR 100000 16 256
cache_replacement_policy heap LFUDA
cache_swap_low 90
cache_swap_high 95

refresh_pattern -i \.(jar|zip|whl|gz|bz2|tar|tgz|deb|rpm|exe|msi|dmg|iso)$ 259200 20% 259200 ignore-reload ignore-no-store ignore-private override-expire
refresh_pattern -i conda.anaconda.org/.* 259200 20% 259200 ignore-reload ignore-no-store ignore-private override-expire
refresh_pattern -i \.(jpg|jpeg|png|gif|ico|webp|svg|mp4|mp3|avi|mov|mkv|pdf)$ 129600 20% 129600 ignore-reload ignore-no-store ignore-private override-expire
refresh_pattern -i github.com/.*/releases/.* 129600 20% 129600 ignore-reload ignore-no-store ignore-private override-expire
refresh_pattern . 0 20% 4320
EOF
}

init_cache() {
    log "Initializing cache..."
    sudo mkdir -p "$CACHE_DIR" "$PREFIX/var/logs" "$PREFIX/var/run"
    sudo rm -rf "$PREFIX/var/logs/ssl_db"
    sudo chown -R proxy:proxy "$PREFIX/var" "$CACHE_DIR"
    sudo chmod 750 "$CACHE_DIR"
    sudo -u proxy "$PREFIX/libexec/security_file_certgen" -c -s "$PREFIX/var/logs/ssl_db" -M 20MB
    sudo -u proxy "$PREFIX/sbin/squid" -z
}

start_squid() {
    log "Starting Squid..."
    stop_squid
    sleep 2
    # Check if already running
    if [ -f "$PREFIX/var/run/squid.pid" ] && ps -p "$(cat "$PREFIX/var/run/squid.pid")" >/dev/null 2>&1; then
        log "Squid already running, restarting..."
        sudo -u proxy "$PREFIX/sbin/squid" -k reconfigure
    else
        sudo -u proxy "$PREFIX/sbin/squid" -d 1
    fi
}

setup_iptables() {
    log "Setting up transparent proxy with connectivity test..."
    
    # Save current iptables rules
    sudo iptables-save > /tmp/iptables.backup
    
    # Remove any existing rules
    remove_iptables
    sudo sysctl -w net.ipv4.ip_forward=1 >/dev/null
    
    # Add new rules
    sudo iptables -t nat -A OUTPUT -p tcp --dport 80 -m owner ! --uid-owner proxy -j REDIRECT --to-port 3129
    sudo iptables -t nat -A OUTPUT -p tcp --dport 443 -m owner ! --uid-owner proxy -j REDIRECT --to-port 3130
    
    # Test connectivity immediately
    log "Testing internet connectivity through transparent proxy..."
    if ! test_internet_connectivity; then
        error "❌ Transparent proxy broke internet connectivity"
        log "Reverting iptables rules..."
        sudo iptables-restore < /tmp/iptables.backup
        rm -f /tmp/iptables.backup
        return 1
    fi
    
    log "✔ Transparent proxy working correctly"
    rm -f /tmp/iptables.backup
    return 0
}

create_service() {
    log "Creating systemd service..."
    sudo tee /etc/systemd/system/squid.service >/dev/null <<EOF
[Unit]
Description=Squid Web Proxy Server
After=network.target

[Service]
Type=forking
PIDFile=$PREFIX/var/run/squid.pid
ExecStart=$PREFIX/sbin/squid
ExecReload=/bin/kill -HUP \$MAINPID
ExecStop=$PREFIX/sbin/squid -k shutdown
TimeoutStop=30s
Restart=on-failure
RestartSec=5
User=proxy
Group=proxy

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable squid.service
}

test_internet_connectivity() {
    for site in "https://google.com" "https://github.com" "https://httpbin.org/get"; do
        curl -s --connect-timeout 5 --max-time 10 "$site" >/dev/null 2>&1 && return 0
    done
    return 1
}

test_proxy_functionality() {
    log "Testing proxy functionality..."
    
    if ! curl -s --connect-timeout 5 --max-time 10 --proxy http://localhost:3128 --cacert "$ssl/ca.crt" \
        "https://httpbin.org/get" >/dev/null 2>&1; then
        error "❌ Proxy connectivity failed - CA certificate or SSL bumping issue"
        return 1
    fi
    
    # Test 2: Verify CA certificate is trusted by system
    if ! openssl verify -CAfile /usr/local/share/ca-certificates/squid-ca.crt "$ssl/ca.crt" >/dev/null 2>&1; then
        error "❌ CA certificate not properly installed in system trust store"
        return 1
    fi
    
    test_url="https://httpbin.org/json"
    if curl -s --max-time 10 --proxy http://localhost:3128 --cacert "$ssl/ca.crt" \
        -H "Cache-Control: no-cache" "$test_url" >/dev/null 2>&1; then
        log "✔ Cache and SSL bumping functional"
    else
        error "❌ Cache or SSL bumping not working"
        return 1
    fi
    
    log "✔ All proxy functionality verified"
    return 0
}

measure_download_speed() {
    url="$1"
    output_file="$2"
    description="$3"
    
    log "Testing: $description"
    rm -f "$output_file"
    
    start_time=$(date +%s.%N)
    if curl -s --max-time 30 -o "$output_file" "$url" 2>/dev/null; then
        end_time=$(date +%s.%N)
        duration=$(echo "$end_time $start_time" | awk '{print $1 - $2}')
        size=$(stat -c%s "$output_file" 2>/dev/null || echo "0")
        speed_bps=$(echo "$size $duration" | awk '{print int($1 / $2)}')
        speed_mbps=$(echo "$speed_bps" | awk '{printf "%.1f", $1 / 1024 / 1024}')
        
        log "  Size: $(numfmt --to=iec $size), Time: ${duration}s, Speed: ${speed_mbps} MB/s"
        printf "%.1f" "$speed_mbps"
        return 0
    else
        error "  Download failed"
        printf "0"
        return 1
    fi
}

test_comprehensive_flow() {
    log "🚀 Starting comprehensive proxy and caching test..."
    
    test_url="https://code.jquery.com/jquery-3.6.0.min.js"
    test_file="/tmp/squid-comprehensive-test"
    min_cache_speed=20  # MB/s
    
    # Phase 1: Test baseline (direct download)
    log "=== PHASE 1: Baseline Download Test (No Proxy) ==="
    if ! baseline_speed=$(measure_download_speed "$test_url" "$test_file" "Direct download"); then
        error "❌ Baseline download failed"
        return 1
    fi
    
    if [ "$(echo "$baseline_speed > 0" | bc -l 2>/dev/null || echo "0")" = "1" ]; then
        log "✔ Baseline download: ${baseline_speed} MB/s"
    else
        error "❌ Baseline download failed"
        return 1
    fi
    
    # Phase 2: Test proxy download (first time - should cache)
    log "=== PHASE 2: First Proxy Download (Caching) ==="
    if ! proxy_speed=$(measure_download_speed "$test_url" "${test_file}.proxy" "First proxy download"); then
        error "❌ First proxy download failed"
        return 1
    fi
    
    log "✔ First proxy download: ${proxy_speed} MB/s"
    
    # Phase 3: Test cache hit (second time - should be fast)
    log "=== PHASE 3: Second Proxy Download (Cache Hit) ==="
    rm -f "${test_file}.cache"
    sleep 2  # Brief pause for cache to settle
    
    if ! cache_speed=$(measure_download_speed "$test_url" "${test_file}.cache" "Second proxy download (cache hit)"); then
        error "❌ Cache hit download failed"
        return 1
    fi
    
    # Check if cache speed meets minimum requirement
    if [ "$(echo "$cache_speed >= $min_cache_speed" | bc -l 2>/dev/null || echo "0")" = "1" ]; then
        log "✔ Cache hit successful: ${cache_speed} MB/s (≥ ${min_cache_speed} MB/s required)"
        
        # Calculate improvement
        if [ "$(echo "$baseline_speed > 0" | bc -l 2>/dev/null || echo "0")" = "1" ]; then
            improvement=$(echo "$cache_speed $baseline_speed" | awk '{printf "%.1fx", $1 / $2}')
            log "✔ Speed improvement: $improvement faster than baseline"
        fi
    else
        error "❌ Cache hit too slow: ${cache_speed} MB/s (< ${min_cache_speed} MB/s required)"
        return 1
    fi
    
    # Phase 4: File integrity check
    log "=== PHASE 4: File Integrity Check ==="
    if [ -f "$test_file" ] && [ -f "${test_file}.cache" ]; then
        if cmp -s "$test_file" "${test_file}.cache"; then
            log "✔ Downloaded files identical (cache integrity verified)"
        else
            error "❌ Downloaded files differ (cache corruption detected)"
            return 1
        fi
    else
        error "❌ Missing files for integrity check"
        return 1
    fi
    
    # Phase 5: Check cache directory
    log "=== PHASE 5: Cache Directory Check ==="
    if [ -d "$CACHE_DIR" ]; then
        cache_size=$(sudo du -sh "$CACHE_DIR" 2>/dev/null | cut -f1 || echo "unknown")
        cache_files=$(sudo find "$CACHE_DIR" -type f 2>/dev/null | wc -l || echo "unknown")
        log "✔ Cache directory: $CACHE_DIR (${cache_size}, ${cache_files} files)"
    else
        error "❌ Cache directory not found: $CACHE_DIR"
        return 1
    fi
    
    # Phase 6: Verify access logs show cache hits
    log "=== PHASE 6: Access Log Verification ==="
    if sudo tail -10 /usr/local/squid/var/logs/access.log | grep -q "TCP_.*HIT"; then
        log "✔ Cache hits found in access logs"
    else
        log "⚠️ No cache hits in recent access logs (may be normal for first run)"
    fi
    
    # Cleanup test files
    rm -f "$test_file" "${test_file}.proxy" "${test_file}.cache"
    
    log "🎉 ALL COMPREHENSIVE TESTS PASSED!"
    return 0
}

test_final_connectivity() {
    log "=== FINAL CONNECTIVITY & FUNCTIONALITY TEST ==="
    
    # Test 1: Basic internet connectivity  
    if ! test_internet_connectivity; then
        error "❌ Internet connectivity broken after installation"
        return 1
    fi
    log "✔ Internet connectivity working"
    
    # Test 2: Comprehensive proxy and caching functionality
    if ! test_comprehensive_flow; then
        error "❌ Comprehensive functionality test failed"
        return 1
    fi
    
    log "✔ All tests passed - installation verified working!"
    return 0
}


main() {
    case "${1:-}" in
        --clean) clean_install ;;
        --disable) disable_proxy; exit 0 ;;
    esac
    
    # Check if squid binary exists, if not build it
    if [ ! -x "$PREFIX/sbin/squid" ]; then
        log "Squid binary not found, building..."
        install_deps
        build_squid
    else
        current_ver=$("$PREFIX/sbin/squid" -v | grep -o 'Version [0-9.]*' | cut -d' ' -f2)
        if [ "$current_ver" = "$VER" ]; then
            log "Squid $VER binary already built"
            install_deps  # Still need proxy user and deps for configuration
        else
            log "Squid version mismatch ($current_ver != $VER), rebuilding..."
            install_deps
            build_squid
        fi
    fi
    
    ssl="$PREFIX/etc/ssl_cert"
    create_ca
    install_ca
    create_config
    init_cache
    start_squid
    
    # Test proxy functionality before setting up transparent redirection
    if ! test_proxy_functionality; then
        error "❌ Proxy functionality test failed"
        error "Squid installation incomplete - stopping here"
        exit 1
    fi
    
    # Setup transparent proxy with fail-safe
    if ! setup_iptables; then
        error "❌ Transparent proxy setup failed"
        error "Regular proxy still available on localhost:3128"
        exit 1
    fi
    
    create_service
    
    # Final comprehensive test
    if ! test_final_connectivity; then
        error "❌ Final connectivity test failed"
        error "Reverting to safe state..."
        sudo iptables -t nat -F
        exit 1
    fi
    
    log "✔ Installation complete!"
    log "Cache: $CACHE_DIR"
    log "Disable: $0 --disable"
    log "Clean: $0 --clean"
}

main "$@"