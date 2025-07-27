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
run_as_user() { sudo -u "$SUDO_USER" -i "$@"; }
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

remove_tool_proxy_configs() {
    log "Removing all proxy configurations from development tools..."
    
    # Git proxy configuration
    if run_as_user git config --global --get http.proxy >/dev/null 2>&1; then
        run_as_user git config --global --unset http.proxy 2>/dev/null || true
        run_as_user git config --global --unset https.proxy 2>/dev/null || true
        run_as_user git config --global --unset http.sslverify 2>/dev/null || true
        log "Git proxy configuration removed"
    fi
    
    # NPM proxy configuration
    if run_as_user bash -c 'command -v npm' >/dev/null 2>&1; then
        run_as_user npm config delete proxy 2>/dev/null || true
        run_as_user npm config delete https-proxy 2>/dev/null || true
        log "NPM proxy configuration removed"
    fi
    
    # Yarn proxy configuration
    if run_as_user bash -c 'command -v yarn' >/dev/null 2>&1; then
        run_as_user yarn config delete proxy 2>/dev/null || true
        run_as_user yarn config delete https-proxy 2>/dev/null || true
        log "Yarn proxy configuration removed"
    fi
    
    # Bun proxy configuration (uses npm config or env vars)
    if run_as_user bash -c 'command -v bun' >/dev/null 2>&1; then
        # Bun typically uses npm config or environment variables
        log "Bun will use environment variables (removed with global proxy cleanup)"
    fi
    
    # Go/Golang proxy configuration (uses env vars GOPROXY, GOSUMDB, etc.)
    if run_as_user bash -c 'command -v go' >/dev/null 2>&1; then
        run_as_user go env -u GOPROXY 2>/dev/null || true
        run_as_user go env -u GOSUMDB 2>/dev/null || true
        log "Go proxy configuration removed"
    fi
    
    # PIP proxy configuration
    run_as_user rm -f "$USER_HOME/.config/pip/pip.conf" 2>/dev/null || true
    run_as_user rm -f "$USER_HOME/.pip/pip.conf" 2>/dev/null || true
    log "PIP proxy configuration removed"
    
    # Wget proxy configuration
    run_as_user rm -f "$USER_HOME/.wgetrc" 2>/dev/null || true
    log "Wget proxy configuration removed"
    
    # Curl proxy configuration  
    run_as_user rm -f "$USER_HOME/.curlrc" 2>/dev/null || true
    log "Curl proxy configuration removed"
    
    # Docker client proxy configuration
    if [ -f "$USER_HOME/.docker/config.json" ]; then
        # Backup and remove proxies section
        run_as_user cp "$USER_HOME/.docker/config.json" "$USER_HOME/.docker/config.json.bak" 2>/dev/null || true
        # Use jq if available, otherwise manual removal
        if command -v jq >/dev/null 2>&1; then
            run_as_user jq 'del(.proxies)' "$USER_HOME/.docker/config.json" > "$USER_HOME/.docker/config.json.tmp" 2>/dev/null || true
            run_as_user mv "$USER_HOME/.docker/config.json.tmp" "$USER_HOME/.docker/config.json" 2>/dev/null || true
        else
            # Fallback: remove entire file if it only contains proxy config
            if grep -q '"proxies"' "$USER_HOME/.docker/config.json" 2>/dev/null; then
                run_as_user rm -f "$USER_HOME/.docker/config.json" 2>/dev/null || true
                log "Docker client config removed (contained only proxy settings)"
            fi
        fi
        log "Docker client proxy configuration removed"
    fi
    
    # Docker daemon proxy configuration
    if [ -f /etc/systemd/system/docker.service.d/http-proxy.conf ]; then
        rm -f /etc/systemd/system/docker.service.d/http-proxy.conf
        # Remove directory if empty
        rmdir /etc/systemd/system/docker.service.d 2>/dev/null || true
        if command -v docker >/dev/null 2>&1; then
            systemctl daemon-reload
            log "Docker daemon proxy configuration removed"
        fi
    fi
    
    # Cargo proxy configuration
    run_as_user rm -f "$USER_HOME/.cargo/config.toml" 2>/dev/null || true
    log "Cargo proxy configuration removed"
    
    # APT proxy configuration
    rm -f /etc/apt/apt.conf.d/99proxy 2>/dev/null || true
    rm -f /usr/local/bin/apt-proxy-detect 2>/dev/null || true
    log "APT proxy configuration removed"
    
    # Remove proxy settings from user's .profile
    if [ -f "$USER_HOME/.profile" ]; then
        # Create a backup
        run_as_user cp "$USER_HOME/.profile" "$USER_HOME/.profile.bak" 2>/dev/null || true
        # Remove proxy-related lines added by squid installer (including incomplete blocks)
        run_as_user sed -i '/# Proxy settings with fallback (added by squid installer)/,/^export no_proxy=/d' "$USER_HOME/.profile" 2>/dev/null || true
        # Remove any remaining proxy-related lines that might have been manually added
        run_as_user sed -i '/HTTP_PROXY.*3128/d; /http_proxy.*3128/d; /HTTPS_PROXY.*3128/d; /https_proxy.*3128/d; /NO_PROXY.*localhost/d; /no_proxy.*localhost/d' "$USER_HOME/.profile" 2>/dev/null || true
        # Remove incomplete proxy blocks
        run_as_user sed -i '/if.*nc.*localhost.*3128/d; /^fi$/d' "$USER_HOME/.profile" 2>/dev/null || true
        log "User .profile proxy settings removed"
    fi
    
    log "All development tool proxy configurations removed"
}

uninstall() {
    log "Removing Squid installation (preserving build)..."
    cleanup
    
    # Remove all proxy configurations from development tools
    remove_tool_proxy_configs

    # Remove proxy user
    if id proxy >/dev/null 2>&1; then
        pkill -9 -u proxy 2>/dev/null || true
        userdel -rf proxy 2>/dev/null || true
    fi

    # Remove only configuration and runtime files, NEVER the build
    rm -rf "$PREFIX/etc" "$PREFIX/var" "$CACHE_DIR" /etc/systemd/system/squid.service
    systemctl daemon-reload
    log "Uninstall complete (build preserved)"
    log "All proxy configurations have been removed from the system"
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
    openssl dhparam -outform PEM -out "$tmp/dhparam.pem" 2048 2>/dev/null

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

apply_config_substitutions() {
    local file="$1"
    # Process all template variables in a single pass
    sed -i \
        -e "s|{{PREFIX}}|$PREFIX|g" \
        -e "s|{{PROXY_PORT}}|$PROXY_PORT|g" \
        -e "s|{{CACHE_DIR}}|$CACHE_DIR|g" \
        -e "s|{{SSL_DIR}}|$SSL_DIR|g" \
        -e "s|{{STD_HTTP_PORT}}|80|g" \
        -e "s|{{STD_HTTPS_PORT}}|443|g" \
        -e "s|{{HTTP_INTERCEPT_PORT}}|3129|g" \
        -e "s|{{HTTPS_INTERCEPT_PORT}}|3130|g" \
        -e "s|{{TCP_KEEPALIVE}}|60,30,3|g" \
        -e "s|{{SSL_CERT_CACHE_SIZE}}|20MB|g" \
        -e "s|{{SSLCRTD_CHILDREN}}|5|g" \
        -e "s|{{SQUID_SSL_DB_SIZE}}|20MB|g" \
        -e "s|{{CACHE_MAX_OBJECT_SIZE}}|50 GB|g" \
        -e "s|{{CACHE_MEM_SIZE}}|8192 MB|g" \
        -e "s|{{CACHE_DIR_SIZE}}|100000|g" \
        -e "s|{{CACHE_L1_DIRS}}|16|g" \
        -e "s|{{CACHE_L2_DIRS}}|256|g" \
        -e "s|{{CACHE_SWAP_LOW}}|90|g" \
        -e "s|{{CACHE_SWAP_HIGH}}|95|g" \
        -e "s|{{CACHE_PERCENTAGE}}|20|g" \
        -e "s|{{CACHE_REFRESH_LARGE_SECONDS}}|259200|g" \
        -e "s|{{CACHE_REFRESH_CONDA_SECONDS}}|129600|g" \
        -e "s|{{CACHE_REFRESH_MEDIA_SECONDS}}|86400|g" \
        -e "s|{{CACHE_REFRESH_GITHUB_SECONDS}}|86400|g" \
        -e "s|{{CACHE_REFRESH_DEFAULT_SECONDS}}|259200|g" \
        -e "s|{{RESTART_DELAY}}|5s|g" \
        "$file"
}

create_config() {
    log "Creating configuration..."
    cp "$CONFIG_DIR/mime.conf.template" "$PREFIX/etc/mime.conf"
    cp "$CONFIG_DIR/squid.conf.template" "$PREFIX/etc/squid.conf"
    apply_config_substitutions "$PREFIX/etc/squid.conf"
    chown proxy:proxy "$PREFIX/etc/mime.conf" "$PREFIX/etc/squid.conf"
}

init_cache() {
    log "Initializing cache..."

    # Ensure cache directories exist and have correct ownership
    mkdir -p "$(dirname "$CACHE_DIR")" "$CACHE_DIR" "$PREFIX/var/logs" "$PREFIX/var/run"
    rm -rf "$PREFIX/var/logs/ssl_db" "$CACHE_DIR"/* 2>/dev/null || true

    # Remove any stale PID files that might interfere with squid -z
    rm -f "$PREFIX/var/run/squid.pid"

    # Ensure directories have correct ownership and permissions
    chown -R proxy:proxy "$PREFIX/var" "$CACHE_DIR"
    chmod 755 "$PREFIX/var/run" "$PREFIX/var/logs"

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

create_proxy_env_content() {
    local shell_type="$1"
    local proxy_url="http://localhost:$PROXY_PORT"
    local no_proxy="localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
    
    case "$shell_type" in
        "bash")
            cat << EOF
# Proxy settings with fallback - only set if squid is running
if command -v nc >/dev/null 2>&1 && nc -z localhost $PROXY_PORT 2>/dev/null; then
    export HTTP_PROXY=$proxy_url
    export HTTPS_PROXY=$proxy_url
    export http_proxy=$proxy_url
    export https_proxy=$proxy_url
fi
export NO_PROXY=$no_proxy
export no_proxy=$no_proxy
EOF
            ;;
        "fish")
            cat << EOF
# Proxy settings with fallback - only set if squid is running
if command -s nc >/dev/null 2>&1; and nc -z localhost $PROXY_PORT 2>/dev/null
    set -gx HTTP_PROXY $proxy_url
    set -gx HTTPS_PROXY $proxy_url
    set -gx http_proxy $proxy_url
    set -gx https_proxy $proxy_url
end
set -gx NO_PROXY $no_proxy
set -gx no_proxy $no_proxy
EOF
            ;;
    esac
}

setup_global_proxy() {
    log "Setting up global proxy environment..."
    rm -f /etc/environment.d/99-proxy.conf

    create_proxy_env_content "bash" > /etc/profile.d/proxy.sh
    chmod +x /etc/profile.d/proxy.sh

    mkdir -p /etc/fish/conf.d
    create_proxy_env_content "fish" > /etc/fish/conf.d/proxy.fish

    if [ -f "$USER_HOME/.profile" ] && ! grep -q "HTTP_PROXY.*$PROXY_PORT" "$USER_HOME/.profile"; then
        {
            echo ""
            echo "# Proxy settings with fallback (added by squid installer)"
            echo "# Only set proxy if squid is running, otherwise apps work without proxy"
            create_proxy_env_content "bash"
        } | run_as_user tee -a "$USER_HOME/.profile" > /dev/null
        log "Updated user's .profile with fallback proxy settings"
    fi
}

create_service() {
    log "Creating systemd service..."
    cp "$CONFIG_DIR/squid.service.template" /etc/systemd/system/squid.service
    apply_config_substitutions /etc/systemd/system/squid.service
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

create_config_file() {
    local tool="$1" config_path="$2" content="$3"
    run_as_user mkdir -p "$(dirname "$config_path")" 
    [ -f "$config_path" ] && run_as_user cp "$config_path" "$config_path.bak" 2>/dev/null || true
    run_as_user tee "$config_path" > /dev/null << EOF
$content
EOF
    log "$tool proxy configured"
}

configure_tool_proxy() {
    local tool="$1" proxy_url="$2" no_proxy="$3"
    
    case "$tool" in
        "git")
            run_as_user git config --global http.proxy "$proxy_url"
            run_as_user git config --global https.proxy "$proxy_url"
            run_as_user git config --global http.sslverify false
            ;;
        "npm")
            run_as_user npm config set proxy "$proxy_url"
            run_as_user npm config set https-proxy "$proxy_url"
            ;;
        "yarn")
            if run_as_user yarn config set proxy "$proxy_url" 2>/dev/null && run_as_user yarn config set https-proxy "$proxy_url" 2>/dev/null; then
                return 0
            else
                log "yarn found but configuration failed (may need installation)"
                return 1
            fi
            ;;
        "pip")
            create_config_file "pip" "$USER_HOME/.config/pip/pip.conf" "[global]
proxy = $proxy_url
trusted-host = pypi.org pypi.python.org files.pythonhosted.org"
            run_as_user mkdir -p "$USER_HOME/.pip"
            run_as_user cp "$USER_HOME/.config/pip/pip.conf" "$USER_HOME/.pip/pip.conf"
            ;;
        "wget")
            create_config_file "wget" "$USER_HOME/.wgetrc" "use_proxy = yes
http_proxy = $proxy_url
https_proxy = $proxy_url
no_proxy = $no_proxy"
            ;;
        "curl")
            create_config_file "curl" "$USER_HOME/.curlrc" "proxy = \"$proxy_url\"
noproxy = \"$no_proxy\""
            ;;
        "docker")
            create_config_file "Docker client" "$USER_HOME/.docker/config.json" "{
  \"proxies\": {
    \"default\": {
      \"httpProxy\": \"$proxy_url\",
      \"httpsProxy\": \"$proxy_url\",
      \"noProxy\": \"$no_proxy\"
    }
  }
}"
            ;;
        "cargo")
            create_config_file "Cargo" "$USER_HOME/.cargo/config.toml" "
[http]
proxy = \"$proxy_url\"

[https]
proxy = \"$proxy_url\""
            ;;
    esac
    log "$tool proxy configured"
}

configure_dev_tools() {
    log "Configuring development tools to use proxy..."
    local proxy_url="http://localhost:$PROXY_PORT"
    local no_proxy="localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"

    configure_tool_proxy "git" "$proxy_url" "$no_proxy"
    configure_tool_proxy "pip" "$proxy_url" "$no_proxy"
    configure_tool_proxy "wget" "$proxy_url" "$no_proxy"
    configure_tool_proxy "curl" "$proxy_url" "$no_proxy"

    # Configure tools that may not be installed
    run_as_user bash -c 'command -v npm' &> /dev/null && configure_tool_proxy "npm" "$proxy_url" "$no_proxy"
    run_as_user bash -c 'command -v yarn' &> /dev/null && configure_tool_proxy "yarn" "$proxy_url" "$no_proxy"
    command -v docker &> /dev/null && {
        configure_tool_proxy "docker" "$proxy_url" "$no_proxy"
        # Docker daemon configuration
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
    }
    command -v cargo &> /dev/null && configure_tool_proxy "cargo" "$proxy_url" "$no_proxy"

    # Configure apt with fallback script
    if command -v apt &> /dev/null; then
        cat > /etc/apt/apt.conf.d/99proxy << 'EOF'
// Dynamic proxy configuration with fallback
Acquire::http::ProxyAutoDetect "/usr/local/bin/apt-proxy-detect";
Acquire::https::ProxyAutoDetect "/usr/local/bin/apt-proxy-detect";
EOF
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


test() {
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
    if run_as_user bash -c 'command -v pip' &> /dev/null; then
        echo -n "• pip: "
        if run_as_user timeout 15 pip config list 2>&1 | grep -q proxy; then
            echo "✓ configured"
        else
            echo "⚠ not configured"
        fi
    fi

    # Test npm
    if run_as_user bash -c 'command -v npm' &> /dev/null; then
        echo -n "• npm: "
        if run_as_user npm config get proxy | grep -q "$PROXY_PORT"; then
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


main() {
    # Check config templates exist (only for main install)
    case "${1:-}" in
        --test)
            # Skip template check for test option
            ;;
        *)
            # Check templates for all other options
            for template in ca.conf.template server.conf.template mime.conf.template squid.conf.template squid.service.template; do
                [ -f "$CONFIG_DIR/$template" ] || { error "Missing config template: $CONFIG_DIR/$template"; exit 1; }
            done
            ;;
    esac

    case "${1:-}" in
        --uninstall)
            uninstall
            exit 0
            ;;
        --test)
            test
            exit 0
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  (none)                Install Squid proxy with default settings"
            echo "  --uninstall           Remove Squid installation (preserving build)"
            echo "  --test                Test all dev tools proxy configuration"
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
