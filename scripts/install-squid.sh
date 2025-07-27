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

# Service settings
RESTART_DELAY=5
SSLCRTD_CHILDREN=5
SSL_CERT_CACHE_SIZE=20MB
TCP_KEEPALIVE="60,30,3"

# Test settings
TEST_SLEEP=3
LOG_TAIL=20
MIN_CACHE_SPEED_MBPS=10
MIN_FILE_SIZE=1048576

# URLs
SQUID_URL="https://github.com/squid-cache/squid/archive/refs/tags/SQUID_$(echo $VER | sed 's/\./_/g').tar.gz"
TEST_URL="https://go.dev/dl/go1.24.5.linux-amd64.tar.gz"
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
    sleep 1
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
    
    # CA config
    cat > "$tmp/ca.conf" <<EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
prompt = no
[req_distinguished_name]
C = US
ST = Local
L = Local
O = Squid Proxy Root CA
OU = Certificate Authority
CN = Squid Root CA
[v3_ca]
basicConstraints = critical,CA:TRUE
keyUsage = critical,keyCertSign,cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer:always
EOF

    # Server config
    cat > "$tmp/server.conf" <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no
[req_distinguished_name]
C = US
ST = Local
L = Local
O = Squid Proxy
OU = Server
CN = Squid Proxy Server
[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation,digitalSignature,keyEncipherment
subjectAltName = @alt_names
extendedKeyUsage = serverAuth
[alt_names]
DNS.1 = localhost
DNS.2 = *.local
IP.1 = 127.0.0.1
EOF

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
    
    # Mime config
    cat > "$PREFIX/etc/mime.conf" <<EOF
text/html html htm
text/plain txt
text/css css
application/octet-stream bin exe
image/jpeg jpg jpeg
image/png png
image/gif gif
EOF
    
    # Squid config
    cat > "$PREFIX/etc/squid.conf" <<EOF
acl intermediate_fetching transaction_initiator certificate-fetching
http_access allow intermediate_fetching

acl localnet src 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 127.0.0.0/8
acl SSL_ports port $STD_HTTPS_PORT
acl Safe_ports port $STD_HTTP_PORT 21 $STD_HTTPS_PORT 70 210 1025-65535 280 488 591 777
acl CONNECT method CONNECT

acl step1 at_step SslBump1
acl step2 at_step SslBump2
acl step3 at_step SslBump3

http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow localhost manager
http_access deny manager
http_access allow localnet
http_access allow localhost
http_access deny all

http_port $PROXY_PORT tcpkeepalive=$TCP_KEEPALIVE ssl-bump generate-host-certificates=on dynamic_cert_mem_cache_size=$SSL_CERT_CACHE_SIZE tls-cert=$SSL_DIR/squid-self-signed.crt tls-key=$SSL_DIR/squid-self-signed.key cipher=HIGH:MEDIUM:!LOW:!RC4:!SEED:!IDEA:!3DES:!MD5:!EXP:!PSK:!DSS options=NO_TLSv1,NO_SSLv3 tls-dh=$SSL_DIR/squid-self-signed_dhparam.pem
http_port $HTTP_INTERCEPT_PORT intercept
https_port $HTTPS_INTERCEPT_PORT intercept ssl-bump generate-host-certificates=on dynamic_cert_mem_cache_size=$SSL_CERT_CACHE_SIZE tls-cert=$SSL_DIR/ca.crt tls-key=$SSL_DIR/ca.key

sslcrtd_program $PREFIX/libexec/security_file_certgen -s $PREFIX/var/logs/ssl_db -M 20MB
sslcrtd_children $SSLCRTD_CHILDREN

ssl_bump server-first all
ssl_bump stare all
sslproxy_cert_error deny all

maximum_object_size 50 GB
cache_mem 8192 MB
cache_dir ufs $CACHE_DIR 100000 16 256
cache_replacement_policy heap LFUDA
cache_swap_low 90
cache_swap_high 95

refresh_pattern -i \\.(jar|zip|whl|gz|bz2|tar|tgz|deb|rpm|exe|msi|dmg|iso)$ $(($CACHE_REFRESH_LARGE * 86400)) $CACHE_PERCENTAGE% $(($CACHE_REFRESH_LARGE * 86400))
refresh_pattern -i conda.anaconda.org/.* $(echo "$CACHE_REFRESH_CONDA * 86400" | bc | cut -d. -f1) $CACHE_PERCENTAGE% $(echo "$CACHE_REFRESH_CONDA * 86400" | bc | cut -d. -f1)
refresh_pattern -i \\.(jpg|jpeg|png|gif|ico|webp|svg|mp4|mp3|avi|mov|mkv|pdf)$ $(($CACHE_REFRESH_MEDIA * 86400)) $CACHE_PERCENTAGE% $(($CACHE_REFRESH_MEDIA * 86400))
refresh_pattern -i github.com/.*/releases/.* $(($CACHE_REFRESH_GITHUB * 86400)) $CACHE_PERCENTAGE% $(($CACHE_REFRESH_GITHUB * 86400))
refresh_pattern . 0 $CACHE_PERCENTAGE% $(($CACHE_REFRESH_DEFAULT * 86400))
EOF
    
    chown proxy:proxy "$PREFIX/etc/mime.conf" "$PREFIX/etc/squid.conf"
}

init_cache() {
    log "Initializing cache..."
    
    mkdir -p "$(dirname "$CACHE_DIR")" "$CACHE_DIR" "$PREFIX/var/logs" "$PREFIX/var/run"
    rm -rf "$PREFIX/var/logs/ssl_db" "$CACHE_DIR"/* 2>/dev/null || true
    chown -R proxy:proxy "$PREFIX/var" "$CACHE_DIR"
    
    # SSL cert db
    run_as_proxy "$PREFIX/libexec/security_file_certgen" -c -s "$PREFIX/var/logs/ssl_db" -M 20MB
    
    # Cache dirs
    run_as_proxy "$PREFIX/sbin/squid" -z -f "$PREFIX/etc/squid.conf" || {
        # Manual creation if needed
        for i in $(seq -f "%02g" 0 15); do
            for j in $(seq -f "%02g" 0 15); do
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
    sleep 2
    
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
    for i in 1 2 3; do
        log "Testing connectivity ($i/3)..."
        test_connectivity && { rm -f /tmp/iptables.backup; return 0; }
        pgrep -f "$PREFIX/sbin/squid" >/dev/null || { error "❌ Squid crashed"; break; }
        sleep 2
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
    cat > /etc/systemd/system/squid.service <<EOF
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
RestartSec=$RESTART_DELAY
User=proxy
Group=proxy

[Install]
WantedBy=multi-user.target
EOF
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

measure_speed() {
    url="$1"
    output="$2"
    rm -f "$output"
    
    start=$(date +%s.%N)
    if curl -s -L -o "$output" "$url" 2>/dev/null; then
        end=$(date +%s.%N)
        duration=$(echo "$end $start" | awk '{print $1 - $2}')
        size=$(stat -c%s "$output" 2>/dev/null || echo "0")
        [ "$size" -lt "$MIN_FILE_SIZE" ] && return 1
        speed=$(echo "$size $duration" | awk '{printf "%.1f", $1 / $2 / 1024 / 1024}')
        echo "$speed"
        return 0
    fi
    return 1
}

test_cache() {
    log "Testing cache..."
    
    test_dir="$HOME/tmp"
    mkdir -p "$test_dir"
    
    # Baseline
    log "Baseline test..."
    baseline=$(measure_speed "$TEST_URL" "$test_dir/baseline") || { error "❌ Baseline failed"; return 1; }
    log "✔ Baseline: ${baseline} MB/s"
    
    # First proxy download
    log "First proxy download..."
    first=$(measure_speed "$TEST_URL" "$test_dir/first") || { error "❌ First download failed"; return 1; }
    log "✔ First: ${first} MB/s"
    
    # Cache hit
    sleep $TEST_SLEEP
    log "Cache hit test..."
    cached=$(measure_speed "$TEST_URL" "$test_dir/cached") || { error "❌ Cache test failed"; return 1; }
    
    if [ "$(echo "$cached >= $MIN_CACHE_SPEED_MBPS" | bc -l 2>/dev/null || echo "0")" = "1" ]; then
        log "✔ Cache hit: ${cached} MB/s"
    else
        log "⚠️ Cache speed: ${cached} MB/s (target: ${MIN_CACHE_SPEED_MBPS})"
    fi
    
    # Verify files
    cmp -s "$test_dir/first" "$test_dir/cached" || { error "❌ File mismatch"; return 1; }
    log "✔ File integrity verified"
    
    # Check cache logs
    tail -$LOG_TAIL "$PREFIX/var/logs/access.log" | grep -q "TCP_.*HIT" && log "✔ Cache hits in logs"
    
    rm -rf "$test_dir"
    return 0
}

main() {
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