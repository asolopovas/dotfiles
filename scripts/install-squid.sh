#!/bin/sh
set -eu

# Require sudo
[ "$(id -u)" != "0" ] && { echo "Error: This script requires sudo"; exit 1; }
[ -z "${SUDO_USER:-}" ] && { echo "Error: Run with sudo, not as root"; exit 1; }

# Configuration
VER=7.1
PREFIX=/usr/local/squid
CACHE_DIR=/mnt/d/.cache/web
USER_HOME="/home/$SUDO_USER"
CONFIG_DIR="$(cd "$(dirname "$0")/../config/squid" && pwd)"

# Ports
PROXY_PORT=3128
HTTP_INTERCEPT_PORT=3129
HTTPS_INTERCEPT_PORT=3130
STD_HTTP_PORT=80
STD_HTTPS_PORT=443

# SSL/Certificate
RSA_KEY_SIZE=2048
CERT_VALIDITY_DAYS=365
DH_PARAM_SIZE=2048
SSL_DIR="$PREFIX/etc/ssl_cert"
CA_CERT="/usr/local/share/ca-certificates/squid-ca.crt"
CA_PEM="/etc/ssl/certs/squid-ca.pem"
CA_BUNDLE="/etc/ssl/certs/ca-certificates.crt"
NSSDB_USER="$USER_HOME/.pki/nssdb"
NSSDB_SYSTEM="/etc/pki/nssdb"
JAVA_CACERTS="/etc/ssl/certs/java/cacerts"

# Cache settings (days)
CACHE_REFRESH_LARGE=3
CACHE_REFRESH_CONDA=1.5
CACHE_REFRESH_MEDIA=1
CACHE_REFRESH_GITHUB=1
CACHE_REFRESH_DEFAULT=3
CACHE_PERCENTAGE=20

# Cache configuration
CACHE_MAX_OBJECT_SIZE="50 GB"
CACHE_MEM_SIZE="8192 MB"
CACHE_DIR_SIZE=100000
CACHE_L1_DIRS=16
CACHE_L2_DIRS=256
CACHE_SWAP_LOW=90
CACHE_SWAP_HIGH=95

# Service settings
RESTART_DELAY=5
SSLCRTD_CHILDREN=5
SSL_CERT_CACHE_SIZE=20MB
TCP_KEEPALIVE="60,30,3"

# Test settings
TEST_SLEEP=3
LOG_TAIL=20
SECONDS_PER_DAY=86400
CONNECTIVITY_TEST_RETRIES=3
CACHE_GRID_SIZE=16
SQUID_SSL_DB_SIZE="20MB"
SLEEP_AFTER_KILL=1
SLEEP_BEFORE_START=2

# File permissions
PERM_PRIVATE_KEY=600
PERM_PUBLIC_FILE=644
PERM_DIRECTORY=755

# URLs
SQUID_URL="https://github.com/squid-cache/squid/archive/refs/tags/SQUID_$(echo $VER | sed 's/\./_/g').tar.gz"
TEST_SITES="https://google.com https://github.com https://httpbin.org/get"

log() { gum style --foreground="#00ff00" "$*"; }
error() { gum style --foreground="#ff0000" "$*"; }
run_as_user() { sudo -u "$SUDO_USER" "$@"; }
run_as_proxy() { sudo -u proxy "$@"; }

cleanup() {
    # Stop services
    systemctl stop squid 2>/dev/null || true
    systemctl disable squid 2>/dev/null || true
    pkill -f "^$PREFIX/sbin/squid" 2>/dev/null || true
    sleep $SLEEP_AFTER_KILL
    pkill -9 -f "^$PREFIX/sbin/squid" 2>/dev/null || true
    
    # Remove iptables
    iptables -t nat -D OUTPUT -p tcp --dport $STD_HTTP_PORT -m owner ! --uid-owner proxy -j REDIRECT --to-port $HTTP_INTERCEPT_PORT 2>/dev/null || true
    iptables -t nat -D OUTPUT -p tcp --dport $STD_HTTPS_PORT -m owner ! --uid-owner proxy -j REDIRECT --to-port $HTTPS_INTERCEPT_PORT 2>/dev/null || true
    
    # Remove certificates
    rm -f "$CA_CERT" "$CA_PEM"
    update-ca-certificates --fresh >/dev/null 2>&1 || true
    [ -f "$CA_BUNDLE" ] && sed -i '/# Squid Proxy CA/,/-----END CERTIFICATE-----/d' "$CA_BUNDLE"
    
    # Remove from certificate stores
    for store in "$USER_HOME/.mozilla/firefox"/*default* "$USER_HOME/snap/firefox/common/.mozilla/firefox"/*default*; do
        [ -f "$store/cert9.db" ] && run_as_user certutil -D -n "Squid Root CA" -d "$store" 2>/dev/null || true
    done
    [ -f "$NSSDB_USER/cert9.db" ] && run_as_user certutil -D -n "Squid Root CA" -d sql:"$NSSDB_USER" 2>/dev/null || true
    rm -f /etc/brave/policies/managed/squid-certificates.json /etc/opt/brave/policies/managed/squid-certificates.json 2>/dev/null || true
}

clean_install() {
    log "Cleaning installation..."
    cleanup
    
    # Remove proxy user
    if id proxy >/dev/null 2>&1; then
        pkill -9 -u proxy 2>/dev/null || true
        userdel -rf proxy 2>/dev/null || true
    fi
    
    # Remove files
    rm -rf "$PREFIX/etc" "$PREFIX/var" "$CACHE_DIR" /etc/systemd/system/squid.service
    systemctl daemon-reload
    log "✔ Clean complete"
}

install_deps() {
    log "Installing dependencies..."
    apt-get update -y >/dev/null
    apt-get install -y build-essential autoconf automake libtool libtool-bin \
        libltdl-dev openssl libssl-dev pkg-config wget libnss3-tools libcppunit-dev \
        ldap-utils samba-common-bin winbind >/dev/null
    id proxy >/dev/null 2>&1 || useradd -r -s /bin/false proxy
}

build_squid() {
    [ -x "$PREFIX/sbin/squid" ] && {
        current=$("$PREFIX/sbin/squid" -v | grep -o 'Version [0-9.]*' | cut -d' ' -f2)
        [ "$current" = "$VER" ] && { log "Squid $VER already built"; return 0; }
    }
    
    log "Building Squid $VER..."
    build="/tmp/squid-build-$$"
    rm -rf "$build" && mkdir -p "$build"
    wget -qO "$build/squid.tar.gz" "$SQUID_URL"
    tar -xf "$build/squid.tar.gz" -C "$build"
    cd "$build"/*
    [ -x configure ] || ./bootstrap.sh
    ./configure --with-default-user=proxy --with-openssl --enable-ssl-crtd --prefix="$PREFIX" >/dev/null
    make -j"$(nproc)" >/dev/null
    make install >/dev/null
    cd - >/dev/null
    chown -R proxy:proxy "$PREFIX"
}

create_certs() {
    log "Creating SSL certificates..."
    tmp=$(mktemp -d)
    
    # Copy config templates
    cp "$CONFIG_DIR/ca.conf.template" "$tmp/ca.conf"
    cp "$CONFIG_DIR/server.conf.template" "$tmp/server.conf"

    # Generate certificates
    openssl genrsa -out "$tmp/ca.key" $RSA_KEY_SIZE 2>/dev/null
    openssl req -new -x509 -days $CERT_VALIDITY_DAYS -key "$tmp/ca.key" -out "$tmp/ca.crt" -config "$tmp/ca.conf" 2>/dev/null
    openssl genrsa -out "$tmp/squid-self-signed.key" $RSA_KEY_SIZE 2>/dev/null
    openssl req -new -key "$tmp/squid-self-signed.key" -out "$tmp/server.csr" -config "$tmp/server.conf" 2>/dev/null
    openssl x509 -req -in "$tmp/server.csr" -CA "$tmp/ca.crt" -CAkey "$tmp/ca.key" -CAcreateserial \
        -out "$tmp/squid-self-signed.crt" -days $CERT_VALIDITY_DAYS -extensions v3_req -extfile "$tmp/server.conf" 2>/dev/null
    
    # Convert formats
    openssl x509 -in "$tmp/squid-self-signed.crt" -outform PEM -out "$tmp/squid-self-signed.pem" 2>/dev/null
    openssl x509 -in "$tmp/ca.crt" -outform PEM -out "$tmp/ca.pem" 2>/dev/null
    openssl dhparam -outform PEM -out "$tmp/squid-self-signed_dhparam.pem" $DH_PARAM_SIZE 2>/dev/null
    
    # Install
    mkdir -p "$SSL_DIR"
    cp "$tmp"/* "$SSL_DIR/" 2>/dev/null
    chmod 600 "$SSL_DIR"/*.key
    chmod 644 "$SSL_DIR"/*.crt "$SSL_DIR"/*.pem
    chown -R proxy:proxy "$SSL_DIR"
    rm -rf "$tmp"
}

install_certs() {
    log "Installing CA certificates..."
    
    # System-wide
    cp "$SSL_DIR/ca.pem" "$CA_CERT"
    update-ca-certificates >/dev/null
    cp "$SSL_DIR/ca.pem" "$CA_PEM"
    
    # Firefox
    for profile in "$USER_HOME/.mozilla/firefox"/*default* "$USER_HOME/snap/firefox/common/.mozilla/firefox"/*default*; do
        [ -d "$profile" ] || continue
        [ -f "$profile/cert9.db" ] || run_as_user certutil -N -d "$profile" --empty-password 2>/dev/null || true
        run_as_user certutil -D -n "Squid Root CA" -d "$profile" 2>/dev/null || true
        run_as_user certutil -A -n "Squid Root CA" -t "TCu,Cu,Tu" -i "$SSL_DIR/ca.pem" -d "$profile" 2>/dev/null || true
    done
    
    # Chrome/Chromium
    run_as_user mkdir -p "$(dirname "$NSSDB_USER")"
    [ -f "$NSSDB_USER/cert9.db" ] || run_as_user certutil -N -d sql:"$NSSDB_USER" --empty-password 2>/dev/null || true
    run_as_user certutil -D -n "Squid Root CA" -d sql:"$NSSDB_USER" 2>/dev/null || true
    run_as_user certutil -A -n "Squid Root CA" -t "TCu,Cu,Tu" -i "$SSL_DIR/ca.pem" -d sql:"$NSSDB_USER" 2>/dev/null || true
    
    # System NSS
    mkdir -p "$NSSDB_SYSTEM"
    [ -f "$NSSDB_SYSTEM/cert9.db" ] || certutil -N -d sql:"$NSSDB_SYSTEM" --empty-password 2>/dev/null || true
    certutil -A -n "Squid Root CA" -t "TCu,Cu,Tu" -i "$SSL_DIR/squid-self-signed.pem" -d sql:"$NSSDB_SYSTEM" 2>/dev/null || true
    
    # Java
    [ -f "$JAVA_CACERTS" ] && {
        keytool -delete -keystore "$JAVA_CACERTS" -storepass changeit -alias "squid-ca" 2>/dev/null || true
        keytool -import -trustcacerts -keystore "$JAVA_CACERTS" -storepass changeit -alias "squid-ca" -file "$SSL_DIR/squid-self-signed.pem" -noprompt 2>/dev/null || true
    }
    
    # CA bundle
    [ -f "$CA_BUNDLE" ] && ! grep -q "Squid Proxy CA" "$CA_BUNDLE" && {
        echo -e "\n# Squid Proxy CA" >> "$CA_BUNDLE"
        cat "$SSL_DIR/squid-self-signed.pem" >> "$CA_BUNDLE"
    }
}

create_config() {
    log "Creating configuration..."
    
    # Calculate seconds from days
    CACHE_REFRESH_LARGE_SECONDS=$(($CACHE_REFRESH_LARGE * $SECONDS_PER_DAY))
    CACHE_REFRESH_CONDA_SECONDS=$(echo "$CACHE_REFRESH_CONDA * $SECONDS_PER_DAY" | bc | cut -d. -f1)
    CACHE_REFRESH_MEDIA_SECONDS=$(($CACHE_REFRESH_MEDIA * $SECONDS_PER_DAY))
    CACHE_REFRESH_GITHUB_SECONDS=$(($CACHE_REFRESH_GITHUB * $SECONDS_PER_DAY))
    CACHE_REFRESH_DEFAULT_SECONDS=$(($CACHE_REFRESH_DEFAULT * $SECONDS_PER_DAY))
    
    # Copy and process mime config
    cp "$CONFIG_DIR/mime.conf.template" "$PREFIX/etc/mime.conf"
    
    # Copy and process squid config
    cp "$CONFIG_DIR/squid.conf.template" "$PREFIX/etc/squid.conf"
    
    # Replace placeholders in squid.conf
    sed -i "s|{{PREFIX}}|$PREFIX|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{PROXY_PORT}}|$PROXY_PORT|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{HTTP_INTERCEPT_PORT}}|$HTTP_INTERCEPT_PORT|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{HTTPS_INTERCEPT_PORT}}|$HTTPS_INTERCEPT_PORT|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{STD_HTTP_PORT}}|$STD_HTTP_PORT|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{STD_HTTPS_PORT}}|$STD_HTTPS_PORT|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{TCP_KEEPALIVE}}|$TCP_KEEPALIVE|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{SSL_CERT_CACHE_SIZE}}|$SSL_CERT_CACHE_SIZE|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{SSL_DIR}}|$SSL_DIR|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{SSLCRTD_CHILDREN}}|$SSLCRTD_CHILDREN|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{CACHE_DIR}}|$CACHE_DIR|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{CACHE_PERCENTAGE}}|$CACHE_PERCENTAGE|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{CACHE_REFRESH_LARGE_SECONDS}}|$CACHE_REFRESH_LARGE_SECONDS|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{CACHE_REFRESH_CONDA_SECONDS}}|$CACHE_REFRESH_CONDA_SECONDS|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{CACHE_REFRESH_MEDIA_SECONDS}}|$CACHE_REFRESH_MEDIA_SECONDS|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{CACHE_REFRESH_GITHUB_SECONDS}}|$CACHE_REFRESH_GITHUB_SECONDS|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{CACHE_REFRESH_DEFAULT_SECONDS}}|$CACHE_REFRESH_DEFAULT_SECONDS|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{SQUID_SSL_DB_SIZE}}|$SQUID_SSL_DB_SIZE|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{CACHE_MAX_OBJECT_SIZE}}|$CACHE_MAX_OBJECT_SIZE|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{CACHE_MEM_SIZE}}|$CACHE_MEM_SIZE|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{CACHE_DIR_SIZE}}|$CACHE_DIR_SIZE|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{CACHE_L1_DIRS}}|$CACHE_L1_DIRS|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{CACHE_L2_DIRS}}|$CACHE_L2_DIRS|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{CACHE_SWAP_LOW}}|$CACHE_SWAP_LOW|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{CACHE_SWAP_HIGH}}|$CACHE_SWAP_HIGH|g" "$PREFIX/etc/squid.conf"
    
    chown proxy:proxy "$PREFIX/etc/mime.conf" "$PREFIX/etc/squid.conf"
}

init_cache() {
    log "Initializing cache..."
    
    mkdir -p "$(dirname "$CACHE_DIR")" "$CACHE_DIR" "$PREFIX/var/logs" "$PREFIX/var/run"
    rm -rf "$PREFIX/var/logs/ssl_db" "$CACHE_DIR"/* 2>/dev/null || true
    chown -R proxy:proxy "$PREFIX/var" "$CACHE_DIR"
    
    # SSL cert db
    run_as_proxy "$PREFIX/libexec/security_file_certgen" -c -s "$PREFIX/var/logs/ssl_db" -M $SQUID_SSL_DB_SIZE
    
    # Cache dirs
    run_as_proxy "$PREFIX/sbin/squid" -z -f "$PREFIX/etc/squid.conf" || {
        # Manual creation if needed
        for i in $(seq -f "%02g" 0 $(($CACHE_GRID_SIZE - 1))); do
            for j in $(seq -f "%02g" 0 $(($CACHE_GRID_SIZE - 1))); do
                run_as_proxy mkdir -p "$CACHE_DIR/$i/$j"
            done
        done
        run_as_proxy touch "$CACHE_DIR/swap.state"
    }
}

start_squid() {
    log "Starting Squid..."
    
    # Stop existing
    pkill -f "^$PREFIX/sbin/squid" 2>/dev/null || true
    sleep $SLEEP_BEFORE_START
    
    # Test config
    run_as_proxy "$PREFIX/sbin/squid" -k parse >/dev/null 2>&1 || {
        error "❌ Config test failed"
        run_as_proxy "$PREFIX/sbin/squid" -k parse
        return 1
    }
    
    # Start
    run_as_proxy "$PREFIX/sbin/squid" -d 1
    sleep $TEST_SLEEP
    
    pgrep -f "$PREFIX/sbin/squid" >/dev/null || {
        error "❌ Failed to start"
        tail -$LOG_TAIL "$PREFIX/var/logs/cache.log" 2>/dev/null || true
        return 1
    }
    log "✔ Started successfully"
}

test_connectivity() {
    for site in $TEST_SITES; do
        curl -s -L "$site" >/dev/null 2>&1 && return 0
    done
    return 1
}

setup_iptables() {
    log "Setting up transparent proxy..."
    
    iptables-save > /tmp/iptables.backup
    
    # Remove existing
    iptables -t nat -D OUTPUT -p tcp --dport $STD_HTTP_PORT -m owner ! --uid-owner proxy -j REDIRECT --to-port $HTTP_INTERCEPT_PORT 2>/dev/null || true
    iptables -t nat -D OUTPUT -p tcp --dport $STD_HTTPS_PORT -m owner ! --uid-owner proxy -j REDIRECT --to-port $HTTPS_INTERCEPT_PORT 2>/dev/null || true
    
    # Verify squid is running and listening
    pgrep -f "$PREFIX/sbin/squid" >/dev/null || { error "❌ Squid not running"; return 1; }
    netstat -ln | grep -q ":$HTTP_INTERCEPT_PORT.*LISTEN" || { error "❌ HTTP intercept port not listening"; return 1; }
    netstat -ln | grep -q ":$HTTPS_INTERCEPT_PORT.*LISTEN" || { error "❌ HTTPS intercept port not listening"; return 1; }
    
    # Add rules
    iptables -t nat -A OUTPUT -p tcp --dport $STD_HTTP_PORT -m owner ! --uid-owner proxy -j REDIRECT --to-port $HTTP_INTERCEPT_PORT
    iptables -t nat -A OUTPUT -p tcp --dport $STD_HTTPS_PORT -m owner ! --uid-owner proxy -j REDIRECT --to-port $HTTPS_INTERCEPT_PORT
    
    # Test with failsafe
    for i in $(seq 1 $CONNECTIVITY_TEST_RETRIES); do
        log "Testing connectivity ($i/$CONNECTIVITY_TEST_RETRIES)..."
        test_connectivity && { rm -f /tmp/iptables.backup; return 0; }
        pgrep -f "$PREFIX/sbin/squid" >/dev/null || { error "❌ Squid crashed"; break; }
        sleep $SLEEP_BEFORE_START
    done
    
    # Failsafe restore
    error "❌ Connectivity test failed - restoring"
    iptables-restore < /tmp/iptables.backup 2>/dev/null || iptables -t nat -F
    rm -f /tmp/iptables.backup
    test_connectivity && log "✔ Connectivity restored" || error "❌ CRITICAL: Manual intervention required"
    return 1
}

create_service() {
    log "Creating systemd service..."
    
    # Copy and process service file
    cp "$CONFIG_DIR/squid.service.template" /etc/systemd/system/squid.service
    
    # Replace placeholders
    sed -i "s|{{PREFIX}}|$PREFIX|g" /etc/systemd/system/squid.service
    sed -i "s|{{RESTART_DELAY}}|$RESTART_DELAY|g" /etc/systemd/system/squid.service
    systemctl daemon-reload
    systemctl enable squid.service
}

test_proxy() {
    log "Testing proxy..."
    
    sleep $TEST_SLEEP
    
    # Basic HTTP
    curl -s -L --proxy http://localhost:$PROXY_PORT http://httpbin.org/get >/dev/null 2>&1 || {
        error "❌ HTTP proxy failed"
        return 1
    }
    log "✔ HTTP proxy working"
    
    # HTTPS with CA
    curl -s -L --proxy http://localhost:$PROXY_PORT --cacert "$SSL_DIR/ca.pem" https://httpbin.org/get >/dev/null 2>&1 || {
        curl -s -L --proxy http://localhost:$PROXY_PORT https://httpbin.org/get >/dev/null 2>&1 || {
            error "❌ HTTPS proxy failed"
            return 1
        }
    }
    log "✔ HTTPS proxy working"
    
    return 0
}

main() {
    # Check config templates exist
    for template in ca.conf.template server.conf.template mime.conf.template squid.conf.template squid.service.template; do
        [ -f "$CONFIG_DIR/$template" ] || { error "❌ Missing config template: $CONFIG_DIR/$template"; exit 1; }
    done
    
    case "${1:-}" in
        --clean) clean_install; exit 0 ;;
        --disable) cleanup; exit 0 ;;
    esac
    
    # Build if needed
    [ ! -x "$PREFIX/sbin/squid" ] && {
        install_deps
        build_squid
    } || {
        current=$("$PREFIX/sbin/squid" -v | grep -o 'Version [0-9.]*' | cut -d' ' -f2)
        [ "$current" != "$VER" ] && {
            install_deps
            build_squid
        } || install_deps
    }
    
    create_certs
    install_certs
    create_config
    init_cache
    start_squid
    
    test_proxy || { error "❌ Proxy test failed"; exit 1; }
    
    # Verify certs before transparent proxy
    openssl verify -CAfile "$CA_CERT" "$SSL_DIR/ca.pem" >/dev/null 2>&1 || {
        error "❌ Certificate verification failed"
        exit 1
    }
    
    setup_iptables || {
        error "❌ Transparent proxy setup failed"
        error "Regular proxy available on localhost:$PROXY_PORT"
        exit 1
    }
    
    create_service
    
    test_connectivity || {
        error "❌ Final connectivity test failed"
        iptables -t nat -F
        exit 1
    }
    
    log "✔ Installation complete!"
    log "Cache: $CACHE_DIR"
    log "Disable: $0 --disable"
    log "Clean: $0 --clean"
}

main "$@"