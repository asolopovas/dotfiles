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
clear_proxy_env() { unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY; }

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
    
    # Remove only runtime files, keep the built binary
    rm -rf "$CACHE_DIR" /etc/systemd/system/squid.service
    # Remove config and runtime dirs but preserve the built squid binary
    rm -rf "$PREFIX/etc" "$PREFIX/var" "$PREFIX/libexec/security_file_certgen"
    systemctl daemon-reload
    log "Clean complete"
}

install_deps() {
    log "Installing dependencies..."
    # Clear proxy environment to avoid circular dependency during install
    clear_proxy_env
    env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy \
        apt-get update -y >/dev/null
    env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy \
        apt-get install -y build-essential autoconf automake libtool libtool-bin \
        libltdl-dev openssl libssl-dev pkg-config wget >/dev/null
    id proxy >/dev/null 2>&1 || useradd -r -s /bin/false proxy
}

build_squid() {
    # Check if squid is already built and correct version
    if [ -x "$PREFIX/sbin/squid" ]; then
        current=$("$PREFIX/sbin/squid" -v 2>/dev/null | grep -o 'Version [0-9.]*' | cut -d' ' -f2 2>/dev/null || echo "unknown")
        if [ "$current" = "$VER" ]; then
            log "Squid $VER already built"
            return 0
        else
            log "Found Squid version $current, need $VER - rebuilding..."
        fi
    fi
    
    log "Building Squid $VER..."
    build="/tmp/squid-build-$$"
    rm -rf "$build" && mkdir -p "$build"
    
    # Clear proxy environment for downloading source
    clear_proxy_env
    SQUID_URL="https://github.com/squid-cache/squid/archive/refs/tags/SQUID_$(echo $VER | sed 's/\./_/g').tar.gz"
    
    log "Downloading Squid source..."
    # Ensure no proxy configuration interferes with source download
    if ! env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy \
        wget --no-proxy -qO "$build/squid.tar.gz" "$SQUID_URL"; then
        error "Failed to download Squid source from $SQUID_URL"
        return 1
    fi
    
    log "Extracting source..."
    if ! tar -xf "$build/squid.tar.gz" -C "$build"; then
        error "Failed to extract Squid source"
        return 1
    fi
    
    cd "$build"/* || { error "Failed to enter build directory"; return 1; }
    
    log "Bootstrapping build system..."
    if [ ! -x configure ]; then
        if ! ./bootstrap.sh; then
            error "Bootstrap failed"
            return 1
        fi
    fi
    
    log "Configuring build..."
    if ! ./configure --with-default-user=proxy --with-openssl --enable-ssl-crtd --prefix="$PREFIX" >/dev/null 2>&1; then
        error "Configure failed"
        return 1
    fi
    
    log "Compiling Squid (this may take several minutes)..."
    if ! make -j"$(nproc)" >/dev/null 2>&1; then
        error "Compilation failed"
        return 1
    fi
    
    log "Installing Squid..."
    if ! make install >/dev/null 2>&1; then
        error "Installation failed"
        return 1
    fi
    
    cd - >/dev/null
    chown -R proxy:proxy "$PREFIX"
    log "Squid build and installation completed successfully"
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
    
    # Ensure cache directories exist and have correct ownership
    mkdir -p "$(dirname "$CACHE_DIR")" "$CACHE_DIR" "$PREFIX/var/logs" "$PREFIX/var/run"
    rm -rf "$PREFIX/var/logs/ssl_db" "$CACHE_DIR"/* 2>/dev/null || true
    
    # Remove any stale PID files that might interfere with squid -z
    rm -f "$PREFIX/var/run/squid.pid"
    
    chown -R proxy:proxy "$PREFIX/var" "$CACHE_DIR"
    
    # SSL cert db
    run_as_proxy "$PREFIX/libexec/security_file_certgen" -c -s "$PREFIX/var/logs/ssl_db" -M 20MB
    
    # Initialize cache directories using squid -z (create swap directories)
    if run_as_proxy "$PREFIX/sbin/squid" -z -f "$PREFIX/etc/squid.conf" 2>/dev/null; then
        log "Cache directories initialized successfully"
    else
        log "Squid -z failed, creating cache directories manually..."
        # Manual creation with hex naming (0-F) as squid expects
        for i in 0 1 2 3 4 5 6 7 8 9 A B C D E F; do
            for j in 0 1 2 3 4 5 6 7 8 9 A B C D E F; do
                run_as_proxy mkdir -p "$CACHE_DIR/0$i/0$j"
            done
        done
        run_as_proxy touch "$CACHE_DIR/swap.state"
        log "Manual cache directory creation completed"
    fi
}

setup_global_proxy() {
    log "Setting up global proxy environment..."
    
    # Remove any system-wide proxy environment file to avoid issues when squid is down
    rm -f /etc/environment.d/99-proxy.conf

    # Create shell profile for legacy support with fallback
    cat > /etc/profile.d/proxy.sh << EOF
# Proxy settings with fallback - only set if squid is running
if command -v nc >/dev/null 2>&1 && nc -z localhost $PROXY_PORT 2>/dev/null; then
    export HTTP_PROXY=http://localhost:$PROXY_PORT
    export HTTPS_PROXY=http://localhost:$PROXY_PORT
    export http_proxy=http://localhost:$PROXY_PORT
    export https_proxy=http://localhost:$PROXY_PORT
fi
export NO_PROXY=localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
export no_proxy=localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
EOF
    chmod +x /etc/profile.d/proxy.sh
    
    # Create Fish shell configuration with fallback
    mkdir -p /etc/fish/conf.d
    cat > /etc/fish/conf.d/proxy.fish << EOF
# Proxy settings with fallback - only set if squid is running
if command -s nc >/dev/null 2>&1; and nc -z localhost $PROXY_PORT 2>/dev/null
    set -gx HTTP_PROXY http://localhost:$PROXY_PORT
    set -gx HTTPS_PROXY http://localhost:$PROXY_PORT
    set -gx http_proxy http://localhost:$PROXY_PORT
    set -gx https_proxy http://localhost:$PROXY_PORT
end
set -gx NO_PROXY localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
set -gx no_proxy localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
EOF
    
    # Update user's .profile if it exists with fallback logic
    if [ -f "$USER_HOME/.profile" ] && ! grep -q "HTTP_PROXY.*$PROXY_PORT" "$USER_HOME/.profile"; then
        run_as_user tee -a "$USER_HOME/.profile" > /dev/null << EOF

# Proxy settings with fallback (added by squid installer)
# Only set proxy if squid is running, otherwise apps work without proxy
if nc -z localhost $PROXY_PORT 2>/dev/null; then
    export HTTP_PROXY=http://localhost:$PROXY_PORT
    export HTTPS_PROXY=http://localhost:$PROXY_PORT
    export http_proxy=http://localhost:$PROXY_PORT
    export https_proxy=http://localhost:$PROXY_PORT
fi
export NO_PROXY=localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
export no_proxy=localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
EOF
        log "Updated user's .profile with fallback proxy settings"
    fi
}

create_service() {
    log "Creating systemd service..."
    
    # Copy and process service file
    cp "$CONFIG_DIR/squid.service.template" /etc/systemd/system/squid.service
    
    # Replace placeholders
    sed -i "s|{{PREFIX}}|$PREFIX|g" /etc/systemd/system/squid.service
    sed -i "s|{{RESTART_DELAY}}|5s|g" /etc/systemd/system/squid.service
    
    systemctl daemon-reload
    systemctl enable squid.service
}

start_squid() {
    log "Starting Squid..."
    
    # Check if squid is already running and working
    if systemctl is-active squid >/dev/null 2>&1 && netstat -tlnp 2>/dev/null | grep -q ":$PROXY_PORT.*LISTEN"; then
        # Test if the running squid is functional
        if timeout 5 curl -s --proxy http://localhost:$PROXY_PORT --connect-timeout 2 http://httpbin.org/get >/dev/null 2>&1; then
            log "Squid is already running and functional"
            return 0
        else
            log "Squid is running but not functional, restarting..."
        fi
    fi
    
    # Comprehensive cleanup of any existing squid processes
    systemctl stop squid 2>/dev/null || true
    sleep 2
    
    # Force kill any remaining processes
    pkill -9 -f "squid" 2>/dev/null || true
    sleep 1
    
    # Remove stale PID files and sockets
    rm -f "$PREFIX/var/run/squid.pid"
    rm -f /var/run/squid.pid
    
    # Test config before attempting to start
    if ! run_as_proxy "$PREFIX/sbin/squid" -k parse >/dev/null 2>&1; then
        error "Squid configuration test failed"
        run_as_proxy "$PREFIX/sbin/squid" -k parse
        return 1
    fi
    
    # Ensure systemd service is enabled
    systemctl enable squid 2>/dev/null || true
    systemctl daemon-reload
    
    # Start squid service
    if ! systemctl start squid; then
        error "Failed to start squid systemd service"
        journalctl -u squid --no-pager -n 5
        return 1
    fi
    
    # Wait for squid to start and begin listening
    local retries=0
    while [ $retries -lt 15 ]; do
        if systemctl is-active squid >/dev/null 2>&1 && netstat -tlnp 2>/dev/null | grep -q ":$PROXY_PORT.*LISTEN"; then
            log "Squid started successfully and listening on port $PROXY_PORT"
            return 0
        fi
        sleep 2
        retries=$((retries + 1))
    done
    
    # If we get here, squid failed to start properly
    error "Squid failed to start after 30 seconds"
    systemctl status squid --no-pager -n 5
    journalctl -u squid --no-pager -n 10
    return 1
}

test_proxy() {
    log "Testing proxy..."
    
    # Wait for squid to be fully ready
    local retries=0
    while ! netstat -tlnp 2>/dev/null | grep -q ":$PROXY_PORT.*LISTEN" && [ $retries -lt 15 ]; do
        log "Waiting for squid to be ready..."
        sleep 1
        retries=$((retries + 1))
    done
    
    if [ $retries -eq 15 ]; then
        error "Squid not listening after 15 seconds"
        return 1
    fi
    
    # Test basic HTTP with timeout and better error handling
    if timeout 10 curl -s --proxy http://localhost:$PROXY_PORT --connect-timeout 5 http://httpbin.org/get >/dev/null 2>&1; then
        log "HTTP proxy test passed"
    else
        # Try to diagnose the issue
        if timeout 5 curl -s --connect-timeout 3 http://httpbin.org/get >/dev/null 2>&1; then
            error "HTTP proxy test failed - proxy issue"
        else
            error "HTTP proxy test failed - network connectivity issue"
        fi
        return 1
    fi
    
    log "Proxy is working"
    log "Global proxy environment configured"
    log "All development tools will now use caching proxy"
}

configure_dev_tools() {
    log "Configuring development tools to use proxy..."
    local proxy_url="http://localhost:$PROXY_PORT"
    local no_proxy="localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
    
    # Configure Git
    run_as_user git config --global http.proxy "$proxy_url"
    run_as_user git config --global https.proxy "$proxy_url"
    log "Git proxy configured"
    
    # Configure pip/Python
    run_as_user mkdir -p "$USER_HOME/.config/pip"
    run_as_user tee "$USER_HOME/.config/pip/pip.conf" > /dev/null << EOF
[global]
proxy = $proxy_url
trusted-host = pypi.org pypi.python.org files.pythonhosted.org
EOF
    # Legacy location
    run_as_user mkdir -p "$USER_HOME/.pip"
    run_as_user cp "$USER_HOME/.config/pip/pip.conf" "$USER_HOME/.pip/pip.conf"
    log "pip proxy configured"
    
    # Configure npm/yarn
    if command -v npm &> /dev/null; then
        run_as_user npm config set proxy "$proxy_url"
        run_as_user npm config set https-proxy "$proxy_url"
        log "npm proxy configured"
    fi
    
    if command -v yarn &> /dev/null; then
        run_as_user yarn config set proxy "$proxy_url"
        run_as_user yarn config set https-proxy "$proxy_url"
        log "yarn proxy configured"
    fi
    
    # Configure wget
    run_as_user tee "$USER_HOME/.wgetrc" > /dev/null << EOF
use_proxy = yes
http_proxy = $proxy_url
https_proxy = $proxy_url
no_proxy = $no_proxy
EOF
    log "wget proxy configured"
    
    # Configure curl
    run_as_user tee "$USER_HOME/.curlrc" > /dev/null << EOF
proxy = "$proxy_url"
noproxy = "$no_proxy"
EOF
    log "curl proxy configured"
    
    # Configure Docker
    if command -v docker &> /dev/null; then
        run_as_user mkdir -p "$USER_HOME/.docker"
        [ -f "$USER_HOME/.docker/config.json" ] && run_as_user cp "$USER_HOME/.docker/config.json" "$USER_HOME/.docker/config.json.bak"
        run_as_user tee "$USER_HOME/.docker/config.json" > /dev/null << EOF
{
  "proxies": {
    "default": {
      "httpProxy": "$proxy_url",
      "httpsProxy": "$proxy_url",
      "noProxy": "$no_proxy"
    }
  }
}
EOF
        log "Docker client proxy configured"
        
        # Docker daemon
        if [ -w /etc/systemd/system/docker.service.d ] || true; then
            mkdir -p /etc/systemd/system/docker.service.d
            tee /etc/systemd/system/docker.service.d/http-proxy.conf > /dev/null << EOF
[Service]
Environment="HTTP_PROXY=$proxy_url"
Environment="HTTPS_PROXY=$proxy_url"
Environment="NO_PROXY=$no_proxy"
EOF
            systemctl daemon-reload
            log "Docker daemon proxy configured"
        fi
    fi
    
    # Configure Cargo/Rust
    if command -v cargo &> /dev/null; then
        run_as_user mkdir -p "$USER_HOME/.cargo"
        [ -f "$USER_HOME/.cargo/config.toml" ] && run_as_user cp "$USER_HOME/.cargo/config.toml" "$USER_HOME/.cargo/config.toml.bak"
        run_as_user tee -a "$USER_HOME/.cargo/config.toml" > /dev/null << EOF

[http]
proxy = "$proxy_url"

[https]
proxy = "$proxy_url"
EOF
        log "Cargo proxy configured"
    fi
    
    # Configure apt with fallback script
    if command -v apt &> /dev/null; then
        cat > /etc/apt/apt.conf.d/99proxy << 'EOF'
// Dynamic proxy configuration with fallback
Acquire::http::ProxyAutoDetect "/usr/local/bin/apt-proxy-detect";
Acquire::https::ProxyAutoDetect "/usr/local/bin/apt-proxy-detect";
EOF
        
        # Create proxy detection script for apt
        cat > /usr/local/bin/apt-proxy-detect << 'EOF'
#!/bin/bash
# Check if squid is running, return proxy URL or empty
if nc -z localhost 3128 2>/dev/null; then
    echo "http://localhost:3128"
else
    echo "DIRECT"
fi
EOF
        chmod +x /usr/local/bin/apt-proxy-detect
        log "apt proxy with fallback configured"
    fi
    
    log "Development tools proxy configuration complete"
}

remove_dev_tools_proxy() {
    log "Removing proxy configuration from development tools..."
    
    # Git
    run_as_user git config --global --unset http.proxy 2>/dev/null || true
    run_as_user git config --global --unset https.proxy 2>/dev/null || true
    
    # npm/yarn
    run_as_user npm config delete proxy 2>/dev/null || true
    run_as_user npm config delete https-proxy 2>/dev/null || true
    run_as_user yarn config delete proxy 2>/dev/null || true
    run_as_user yarn config delete https-proxy 2>/dev/null || true
    
    # Remove config files
    rm -f "$USER_HOME/.wgetrc" "$USER_HOME/.curlrc" "$USER_HOME/.pip/pip.conf" "$USER_HOME/.config/pip/pip.conf"
    rm -f "$USER_HOME/.docker/config.json"
    rm -f /etc/apt/apt.conf.d/99proxy /etc/apt/apt.conf.d/95proxy 2>/dev/null || true
    rm -f /usr/local/bin/apt-proxy-detect 2>/dev/null || true
    rm -f /etc/systemd/system/docker.service.d/http-proxy.conf 2>/dev/null || true
    
    log "Proxy configuration removed from development tools"
}

test_dev_tools() {
    log "Testing development tools with proxy..."
    echo ""
    local test_url="http://httpbin.org/get"
    local https_test_url="https://httpbin.org/get"
    local failed=0
    
    # Test curl
    echo -n "• curl: "
    if timeout 10 curl -s "$test_url" >/dev/null 2>&1; then
        echo "✓ working"
    else
        echo "❌ failed"
        ((failed++))
    fi
    
    # Test wget
    echo -n "• wget: "
    if timeout 10 wget -q -O /dev/null "$test_url" 2>&1; then
        echo "✓ working"
    else
        echo "❌ failed"
        ((failed++))
    fi
    
    # Test git
    echo -n "• git (https): "
    if timeout 20 git ls-remote https://github.com/torvalds/linux.git HEAD >/dev/null 2>&1; then
        echo "✓ working"
    else
        echo "❌ failed"
        ((failed++))
    fi
    
    # Test pip
    if command -v pip &> /dev/null; then
        echo -n "• pip: "
        if timeout 15 pip config list 2>&1 | grep -q proxy; then
            echo "✓ configured"
        else
            echo "⚠ not configured"
        fi
    fi
    
    # Test npm
    if command -v npm &> /dev/null; then
        echo -n "• npm: "
        if npm config get proxy | grep -q "$PROXY_PORT"; then
            echo "✓ configured"
        else
            echo "⚠ not configured"
        fi
    fi
    
    # Test docker
    if command -v docker &> /dev/null; then
        echo -n "• docker: "
        if [ -f "$USER_HOME/.docker/config.json" ] && grep -q "$PROXY_PORT" "$USER_HOME/.docker/config.json"; then
            echo "✓ configured"
        else
            echo "⚠ not configured"
        fi
    fi
    
    echo ""
    if [ $failed -eq 0 ]; then
        log "All tools working with proxy"
    else
        error "$failed tools failed proxy test"
        return 1
    fi
}

test_git_clone() {
    log "Testing git clone with proxy..."
    local test_dir="/tmp/squid-git-test-$$"
    local target_dir="${1:-$USER_HOME/src}"
    
    # Ensure target directory exists
    run_as_user mkdir -p "$target_dir"
    
    # Create temp test directory
    mkdir -p "$test_dir"
    cd "$test_dir"
    
    # Test with a small repo first
    echo "Testing with small repository..."
    if timeout 30 run_as_user git clone --depth 1 https://github.com/octocat/Hello-World.git >/dev/null 2>&1; then
        log "Small repo clone successful"
        rm -rf Hello-World
    else
        error "Small repo clone failed"
        cd - >/dev/null
        rm -rf "$test_dir"
        return 1
    fi
    
    # Test with Linux kernel (shallow clone)
    echo "Testing with Linux kernel (shallow clone)..."
    cd "$target_dir"
    if [ -d "linux" ]; then
        log "Linux repo already exists in $target_dir/linux"
    else
        if timeout 120 run_as_user git clone --depth 1 https://github.com/torvalds/linux.git >/dev/null 2>&1; then
            log "Linux kernel clone successful to $target_dir/linux"
        else
            error "Linux kernel clone failed"
            cd - >/dev/null
            rm -rf "$test_dir"
            return 1
        fi
    fi
    
    cd - >/dev/null
    rm -rf "$test_dir"
    log "Git clone tests completed successfully"
}

main() {
    # Check config templates exist (only for main install)
    case "${1:-}" in
        --configure-tools|--remove-tools-config|--test-tools|--test-git-clone)
            # Skip template check for these options
            ;;
        *)
            # Check templates for all other options
            for template in ca.conf.template server.conf.template mime.conf.template squid.conf.template squid.service.template; do
                [ -f "$CONFIG_DIR/$template" ] || { error "Missing config template: $CONFIG_DIR/$template"; exit 1; }
            done
            ;;
    esac
    
    case "${1:-}" in
        --clean) 
            clean_install
            exit 0 
            ;;
        --disable) 
            cleanup
            remove_dev_tools_proxy
            exit 0 
            ;;
        --build-only)
            install_deps
            build_squid
            exit 0
            ;;
        --install-only)
            create_certs
            create_config
            init_cache
            setup_global_proxy
            create_service
            start_squid
            test_proxy
            configure_dev_tools
            exit 0
            ;;
        --configure-tools)
            configure_dev_tools
            exit 0
            ;;
        --remove-tools-config)
            remove_dev_tools_proxy
            exit 0
            ;;
        --test-tools)
            test_dev_tools
            exit 0
            ;;
        --test-git-clone)
            test_git_clone "${2:-}"
            exit 0
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  (none)                Install Squid proxy with default settings"
            echo "  --build-only          Build Squid only (dependencies + compilation)"
            echo "  --install-only        Install and configure only (assumes build exists)"
            echo "  --clean               Complete clean install (removes everything)"
            echo "  --disable             Disable proxy and remove from system"
            echo "  --configure-tools     Configure all dev tools to use proxy"
            echo "  --remove-tools-config Remove proxy config from dev tools"
            echo "  --test-tools          Test all dev tools proxy configuration"
            echo "  --test-git-clone [DIR] Test git clone via proxy (default: ~/src)"
            echo "  --help                Show this help message"
            exit 0
            ;;
        "")
            # Default install flow
            ;;
        *)
            error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
    
    # Main installation flow
    install_deps
    build_squid
    create_certs
    create_config
    init_cache
    setup_global_proxy
    create_service
    start_squid
    test_proxy
    
    # Automatically configure dev tools
    configure_dev_tools
    
    log "Installation complete!"
    log "Cache directory: $CACHE_DIR"
    log "Proxy URL: http://localhost:$PROXY_PORT"
    log "Disable: $0 --disable"
    log "Clean: $0 --clean"
    log ""
    log "All development tools have been configured to use the proxy"
    log "Note: You may need to restart your session for global proxy to take effect"
}

main "$@"