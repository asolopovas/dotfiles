#!/bin/sh
set -eu

# Check if running as root, if not, re-exec with sudo
if [ "$(id -u)" != "0" ]; then
    echo "This script requires sudo privileges. Please enter your password:"
    exec sudo "$0" "$@"
fi

# Ensure we have SUDO_USER (when run via sudo)
[ -z "${SUDO_USER:-}" ] && { echo "Error: Run with sudo, not as root directly"; exit 1; }

# Configuration
VER=7.1
PREFIX=/usr/local/squid
CACHE_DIR=/mnt/d/.cache/web
USER_HOME="/home/$SUDO_USER"
CONFIG_DIR="$(cd "$(dirname "$0")/../config/squid" && pwd)"
PROXY_PORT=3128
SSL_DIR="$PREFIX/etc/ssl_cert"

log() { echo "✓ $*"; }
error() { echo "❌ $*"; }
run_as_user() { sudo -u "$SUDO_USER" "$@"; }
run_as_proxy() { sudo -u proxy "$@"; }

cleanup() {
    log "Cleaning up..."
    systemctl stop squid 2>/dev/null || true
    systemctl disable squid 2>/dev/null || true
    pkill -f "^$PREFIX/sbin/squid" 2>/dev/null || true
    
    # Remove global proxy environment
    rm -f /etc/environment.d/99-proxy.conf
    rm -f /etc/profile.d/proxy.sh
    rm -f /etc/fish/conf.d/proxy.fish
    
    # Remove certificates
    rm -f /usr/local/share/ca-certificates/squid-ca.crt
    update-ca-certificates --fresh >/dev/null 2>&1 || true
}

clean_install() {
    log "Performing clean installation..."
    cleanup
    
    # Remove proxy user
    if id proxy >/dev/null 2>&1; then
        pkill -9 -u proxy 2>/dev/null || true
        userdel -rf proxy 2>/dev/null || true
    fi
    
    # Remove files
    rm -rf "$PREFIX" "$CACHE_DIR" /etc/systemd/system/squid.service
    systemctl daemon-reload
    log "Clean complete"
}

install_deps() {
    log "Installing dependencies..."
    apt-get update -y >/dev/null
    apt-get install -y build-essential autoconf automake libtool libtool-bin \
        libltdl-dev openssl libssl-dev pkg-config wget >/dev/null
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
    SQUID_URL="https://github.com/squid-cache/squid/archive/refs/tags/SQUID_$(echo $VER | sed 's/\./_/g').tar.gz"
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
    openssl genrsa -out "$tmp/ca.key" 2048 2>/dev/null
    openssl req -new -x509 -days 365 -key "$tmp/ca.key" -out "$tmp/ca.crt" -config "$tmp/ca.conf" 2>/dev/null
    openssl genrsa -out "$tmp/squid-self-signed.key" 2048 2>/dev/null
    openssl req -new -key "$tmp/squid-self-signed.key" -out "$tmp/server.csr" -config "$tmp/server.conf" 2>/dev/null
    openssl x509 -req -in "$tmp/server.csr" -CA "$tmp/ca.crt" -CAkey "$tmp/ca.key" -CAcreateserial \
        -out "$tmp/squid-self-signed.crt" -days 365 -extensions v3_req -extfile "$tmp/server.conf" 2>/dev/null
    
    # Convert formats
    openssl x509 -in "$tmp/ca.crt" -outform PEM -out "$tmp/ca.pem" 2>/dev/null
    openssl dhparam -outform PEM -out "$tmp/squid-self-signed_dhparam.pem" 2048 2>/dev/null
    
    # Install
    mkdir -p "$SSL_DIR"
    cp "$tmp"/* "$SSL_DIR/" 2>/dev/null
    chmod 600 "$SSL_DIR"/*.key
    chmod 644 "$SSL_DIR"/*.crt "$SSL_DIR"/*.pem
    chown -R proxy:proxy "$SSL_DIR"
    rm -rf "$tmp"
    
    # Install CA certificate system-wide
    cp "$SSL_DIR/ca.pem" /usr/local/share/ca-certificates/squid-ca.crt
    update-ca-certificates >/dev/null
}

create_config() {
    log "Creating configuration..."
    
    # Copy and process mime config
    cp "$CONFIG_DIR/mime.conf.template" "$PREFIX/etc/mime.conf"
    
    # Copy and process squid config  
    cp "$CONFIG_DIR/squid.conf.template" "$PREFIX/etc/squid.conf"
    
    # Replace placeholders in squid.conf
    sed -i "s|{{PREFIX}}|$PREFIX|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{PROXY_PORT}}|$PROXY_PORT|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{CACHE_DIR}}|$CACHE_DIR|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{SSL_DIR}}|$SSL_DIR|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{STD_HTTP_PORT}}|80|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{STD_HTTPS_PORT}}|443|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{HTTP_INTERCEPT_PORT}}|3129|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{HTTPS_INTERCEPT_PORT}}|3130|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{TCP_KEEPALIVE}}|60,30,3|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{SSL_CERT_CACHE_SIZE}}|20MB|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{SSLCRTD_CHILDREN}}|5|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{SQUID_SSL_DB_SIZE}}|20MB|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{CACHE_MAX_OBJECT_SIZE}}|50 GB|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{CACHE_MEM_SIZE}}|8192 MB|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{CACHE_DIR_SIZE}}|100000|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{CACHE_L1_DIRS}}|16|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{CACHE_L2_DIRS}}|256|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{CACHE_SWAP_LOW}}|90|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{CACHE_SWAP_HIGH}}|95|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{CACHE_PERCENTAGE}}|20|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{CACHE_REFRESH_LARGE_SECONDS}}|259200|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{CACHE_REFRESH_CONDA_SECONDS}}|129600|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{CACHE_REFRESH_MEDIA_SECONDS}}|86400|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{CACHE_REFRESH_GITHUB_SECONDS}}|86400|g" "$PREFIX/etc/squid.conf"
    sed -i "s|{{CACHE_REFRESH_DEFAULT_SECONDS}}|259200|g" "$PREFIX/etc/squid.conf"
    
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

setup_global_proxy() {
    log "Setting up global proxy environment..."
    
    # Create systemd environment file
    cat > /etc/environment.d/99-proxy.conf << EOF
HTTP_PROXY=http://localhost:$PROXY_PORT
HTTPS_PROXY=http://localhost:$PROXY_PORT
http_proxy=http://localhost:$PROXY_PORT
https_proxy=http://localhost:$PROXY_PORT
NO_PROXY=localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
no_proxy=localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
EOF

    # Create shell profile for legacy support
    cat > /etc/profile.d/proxy.sh << EOF
export HTTP_PROXY=http://localhost:$PROXY_PORT
export HTTPS_PROXY=http://localhost:$PROXY_PORT
export http_proxy=http://localhost:$PROXY_PORT
export https_proxy=http://localhost:$PROXY_PORT
export NO_PROXY=localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
export no_proxy=localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
EOF
    chmod +x /etc/profile.d/proxy.sh
    
    # Create Fish shell configuration
    mkdir -p /etc/fish/conf.d
    cat > /etc/fish/conf.d/proxy.fish << EOF
set -gx HTTP_PROXY http://localhost:$PROXY_PORT
set -gx HTTPS_PROXY http://localhost:$PROXY_PORT
set -gx http_proxy http://localhost:$PROXY_PORT
set -gx https_proxy http://localhost:$PROXY_PORT
set -gx NO_PROXY localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
set -gx no_proxy localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
EOF
}

create_service() {
    log "Creating systemd service..."
    
    # Copy and process service file
    cp "$CONFIG_DIR/squid.service.template" /etc/systemd/system/squid.service
    
    # Replace placeholders
    sed -i "s|{{PREFIX}}|$PREFIX|g" /etc/systemd/system/squid.service
    
    systemctl daemon-reload
    systemctl enable squid.service
}

start_squid() {
    log "Starting Squid..."
    
    # Stop existing
    pkill -f "^$PREFIX/sbin/squid" 2>/dev/null || true
    sleep 2
    
    # Test config
    run_as_proxy "$PREFIX/sbin/squid" -k parse >/dev/null 2>&1 || {
        error "Config test failed"
        return 1
    }
    
    # Start via systemctl
    systemctl start squid
    sleep 3
    
    # Verify it's running
    systemctl is-active squid >/dev/null || {
        error "Failed to start squid service"
        return 1
    }
    
    log "Squid started successfully"
}

test_proxy() {
    log "Testing proxy..."
    
    # Test basic HTTP
    curl -s --proxy http://localhost:$PROXY_PORT http://httpbin.org/get >/dev/null 2>&1 || {
        error "HTTP proxy test failed"
        return 1
    }
    
    log "Proxy is working"
    log "Global proxy environment configured"
    log "All development tools will now use caching proxy"
}

main() {
    # Check config templates exist
    for template in ca.conf.template server.conf.template mime.conf.template squid.conf.template squid.service.template; do
        [ -f "$CONFIG_DIR/$template" ] || { error "Missing config template: $CONFIG_DIR/$template"; exit 1; }
    done
    
    case "${1:-}" in
        --clean) clean_install; exit 0 ;;
        --disable) cleanup; exit 0 ;;
    esac
    
    # Build if needed
    install_deps
    build_squid
    
    create_certs
    create_config
    init_cache
    setup_global_proxy
    create_service
    start_squid
    test_proxy
    
    log "Installation complete!"
    log "Cache directory: $CACHE_DIR"
    log "Proxy URL: http://localhost:$PROXY_PORT"
    log "Disable: $0 --disable"
    log "Clean: $0 --clean"
    log ""
    log "Note: You may need to restart your session for global proxy to take effect"
}

main "$@"