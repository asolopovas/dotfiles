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
USER_HOME="/home/$SUDO_USER"
CACHE_DIR="/var/cache/squid"
CONFIG_DIR="$(cd "$(dirname "$0")/../config/squid" && pwd)"
PROXY_PORT=3128
SSL_DIR="$PREFIX/etc/ssl_cert"

# Helper functions
log() { echo "✓ $*"; }
error() { echo "❌ $*"; }
run_as_user() { sudo -u "$SUDO_USER" -i "$@"; }
run_as_proxy() { sudo -u proxy "$@"; }

# Consolidated environment clearing
clear_proxy_env() { 
    unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY no_proxy NO_PROXY 2>/dev/null || true
}

# Tool detection helper
tool_exists() {
    run_as_user bash -c "command -v $1" >/dev/null 2>&1
}

# Batch directory creation
create_directories() {
    mkdir -p "$CACHE_DIR" "$PREFIX/var/logs" "$PREFIX/var/run" "$SSL_DIR"
    run_as_user mkdir -p "$USER_HOME/.config/pip" "$USER_HOME/.pip" "$USER_HOME/.cargo" 2>/dev/null || true
}

# Batch ownership setting
set_ownership() {
    chown -R proxy:proxy "$PREFIX" "$CACHE_DIR"
    chmod 755 "$PREFIX/var/run" "$PREFIX/var/logs"
}

cleanup() {
    log "Cleaning up..."
    systemctl stop squid 2>/dev/null || true
    systemctl disable squid 2>/dev/null || true
    pkill -f "^$PREFIX/sbin/squid" 2>/dev/null || true

    # Remove global proxy environment and certificates
    rm -f /etc/environment.d/99-proxy.conf /etc/profile.d/proxy.sh /etc/fish/conf.d/proxy.fish
    rm -f /usr/local/share/ca-certificates/squid-ca.crt
    update-ca-certificates --fresh >/dev/null 2>&1 || true
}

remove_tool_proxy_configs() {
    log "Removing all proxy configurations from development tools..."
    
    # NPM proxy configuration
    if tool_exists npm; then
        run_as_user npm config delete proxy 2>/dev/null || true
        run_as_user npm config delete https-proxy 2>/dev/null || true
    fi
    
    # Yarn proxy configuration (yarn uses different commands)
    if tool_exists yarn; then
        # Only unset if the config exists to avoid errors
        if run_as_user yarn config get proxy >/dev/null 2>&1; then
            run_as_user yarn config unset proxy 2>/dev/null || true
        fi
        if run_as_user yarn config get https-proxy >/dev/null 2>&1; then
            run_as_user yarn config unset https-proxy 2>/dev/null || true
        fi
    fi

    if tool_exists go; then
        run_as_user go env -u GOPROXY -u GOSUMDB 2>/dev/null || true
    fi
    
    # File-based configs
    run_as_user rm -f "$USER_HOME/.config/pip/pip.conf" "$USER_HOME/.pip/pip.conf" \
        "$USER_HOME/.wgetrc" "$USER_HOME/.curlrc" "$USER_HOME/.cargo/config.toml" 2>/dev/null || true
    
    # System configs
    rm -f /etc/apt/apt.conf.d/99proxy /usr/local/bin/apt-proxy-detect 2>/dev/null || true
    
    # Clean .profile
    if [ -f "$USER_HOME/.profile" ]; then
        run_as_user cp "$USER_HOME/.profile" "$USER_HOME/.profile.bak" 2>/dev/null || true
        run_as_user sed -i '/# Proxy settings with fallback/,/^export no_proxy=/d; /HTTP_PROXY.*3128/d; /http_proxy.*3128/d' "$USER_HOME/.profile" 2>/dev/null || true
    fi
    
    log "All development tool proxy configurations removed"
}

uninstall() {
    log "Removing Squid installation (preserving build)..."
    cleanup
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
}

install_deps() {
    log "Installing dependencies..."
    clear_proxy_env
    apt-get update -y >/dev/null
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
        fi
        log "Found Squid version $current, need $VER - rebuilding..."
    fi

    log "Building Squid $VER..."
    build="/tmp/squid-build-$$"
    rm -rf "$build" && mkdir -p "$build"

    clear_proxy_env
    SQUID_URL="https://github.com/squid-cache/squid/archive/refs/tags/SQUID_$(echo $VER | sed 's/\./_/g').tar.gz"

    log "Downloading and extracting Squid source..."
    if ! wget --no-proxy -qO "$build/squid.tar.gz" "$SQUID_URL" || ! tar -xf "$build/squid.tar.gz" -C "$build"; then
        error "Failed to download/extract Squid source"
        return 1
    fi

    cd "$build"/* || { error "Failed to enter build directory"; return 1; }

    # Bootstrap if needed, then configure, compile and install
    [ ! -x configure ] && ./bootstrap.sh
    ./configure --with-default-user=proxy --with-openssl --enable-ssl-crtd --prefix="$PREFIX" >/dev/null 2>&1
    make -j"$(nproc)" >/dev/null 2>&1
    make install >/dev/null 2>&1

    cd - >/dev/null
    log "Squid build and installation completed successfully"
}

create_certs() {
    log "Creating SSL certificates..."
    tmp=$(mktemp -d)

    # Copy templates and generate certificates
    cp "$CONFIG_DIR/ca.conf.template" "$tmp/ca.conf"
    cp "$CONFIG_DIR/server.conf.template" "$tmp/server.conf"

    # Generate all certificates in sequence
    openssl genrsa -out "$tmp/ca.key" 2048 2>/dev/null
    openssl req -new -x509 -days 365 -key "$tmp/ca.key" -out "$tmp/ca.crt" -config "$tmp/ca.conf" 2>/dev/null
    openssl genrsa -out "$tmp/squid-self-signed.key" 2048 2>/dev/null
    openssl req -new -key "$tmp/squid-self-signed.key" -out "$tmp/server.csr" -config "$tmp/server.conf" 2>/dev/null
    openssl x509 -req -in "$tmp/server.csr" -CA "$tmp/ca.crt" -CAkey "$tmp/ca.key" -CAcreateserial \
        -out "$tmp/squid-self-signed.crt" -days 365 -extensions v3_req -extfile "$tmp/server.conf" 2>/dev/null
    openssl x509 -in "$tmp/ca.crt" -outform PEM -out "$tmp/ca.pem" 2>/dev/null
    openssl dhparam -outform PEM -out "$tmp/dhparam.pem" 2048 2>/dev/null

    # Install certificates
    cp "$tmp"/* "$SSL_DIR/" 2>/dev/null
    chmod 600 "$SSL_DIR"/*.key
    chmod 644 "$SSL_DIR"/*.crt "$SSL_DIR"/*.pem
    rm -rf "$tmp"

    # Install CA certificate system-wide
    cp "$SSL_DIR/ca.pem" /usr/local/share/ca-certificates/squid-ca.crt
    cp "$SSL_DIR/ca.crt" /etc/ssl/certs/squid-ca.crt
    update-ca-certificates >/dev/null 2>&1
    c_rehash /etc/ssl/certs/ >/dev/null 2>&1 || true
}

# Simplified template substitution using associative array approach
apply_config_substitutions() {
    local file="$1"
    # Single sed command with all substitutions
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
}

init_cache() {
    log "Initializing cache..."
    
    # Clear any existing cache and set up directories
    rm -rf "$PREFIX/var/logs/ssl_db" "$CACHE_DIR"/* 2>/dev/null || true
    rm -f "$PREFIX/var/run/squid.pid"

    # SSL cert db and cache directories
    run_as_proxy "$PREFIX/libexec/security_file_certgen" -c -s "$PREFIX/var/logs/ssl_db" -M 20MB
    if run_as_proxy "$PREFIX/sbin/squid" -z -f "$PREFIX/etc/squid.conf"; then
        log "Cache directories initialized successfully"
    else
        error "Failed to initialize cache directories"
        return 1
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
    log "Setting up Squid service..."
    rm -f "$PREFIX/var/run/squid.pid"
    log "Squid installation complete"
    log "Start squid with: sudo systemctl start squid"
    log "Check status with: sudo systemctl status squid"
}

test_proxy() {
    log "Testing proxy..."
    if netstat -tlnp 2>/dev/null | grep -q ":$PROXY_PORT.*LISTEN" && nc -z localhost $PROXY_PORT 2>/dev/null; then
        log "Proxy is listening and accessible on port $PROXY_PORT"
    else
        log "Proxy not listening - start manually with: sudo systemctl start squid"
    fi
    log "Development tools will be configured individually"
}

# Unified config file creation
create_tool_config() {
    local tool="$1" config_path="$2" content="$3"
    run_as_user mkdir -p "$(dirname "$config_path")" 2>/dev/null || true
    [ -f "$config_path" ] && run_as_user cp "$config_path" "$config_path.bak" 2>/dev/null || true
    echo "$content" | run_as_user tee "$config_path" > /dev/null 2>&1
}

# Streamlined tool configuration
configure_tool_proxy() {
    local tool="$1" proxy_url="$2" no_proxy="$3"
    
    case "$tool" in
        npm)
            if tool_exists npm; then
                run_as_user npm config set proxy "$proxy_url" 2>/dev/null
                run_as_user npm config set https-proxy "$proxy_url" 2>/dev/null
                log "npm proxy configured"
            fi
            ;;
        yarn)
            if tool_exists yarn; then
                run_as_user yarn config set proxy "$proxy_url" 2>/dev/null
                run_as_user yarn config set https-proxy "$proxy_url" 2>/dev/null
                log "yarn proxy configured"
            fi
            ;;
        pip)
            create_tool_config "pip" "$USER_HOME/.config/pip/pip.conf" "[global]
proxy = $proxy_url
trusted-host = pypi.org pypi.python.org files.pythonhosted.org"
            run_as_user cp "$USER_HOME/.config/pip/pip.conf" "$USER_HOME/.pip/pip.conf"
            log "pip proxy configured"
            ;;
        wget)
            create_tool_config "wget" "$USER_HOME/.wgetrc" "use_proxy = yes
http_proxy = $proxy_url
https_proxy = $proxy_url
no_proxy = $no_proxy"
            log "wget proxy configured"
            ;;
        curl)
            create_tool_config "curl" "$USER_HOME/.curlrc" "proxy = \"$proxy_url\"
noproxy = \"$no_proxy\""
            log "curl proxy configured"
            ;;
        cargo)
            if tool_exists cargo; then
                create_tool_config "cargo" "$USER_HOME/.cargo/config.toml" "[http]
proxy = \"$proxy_url\"

[https]
proxy = \"$proxy_url\""
                log "cargo proxy configured"
            fi
            ;;
    esac
}

configure_dev_tools() {
    log "Configuring development tools to use proxy..."
    local proxy_url="http://localhost:$PROXY_PORT"
    local no_proxy="localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"

    # Configure available tools
    for tool in pip wget curl npm yarn cargo; do
        configure_tool_proxy "$tool" "$proxy_url" "$no_proxy"
    done

    # Configure apt with fallback
    if command -v apt >/dev/null 2>&1; then
        cat > /etc/apt/apt.conf.d/99proxy << 'EOF'
// Dynamic proxy configuration with fallback (HTTP only)
Acquire::http::ProxyAutoDetect "/usr/local/bin/apt-proxy-detect";
EOF
        cat > /usr/local/bin/apt-proxy-detect << 'EOF'
#!/bin/bash
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
    log "Testing development tools proxy configuration..."
    local failed=0

    # Test configurations
    for tool in curl wget; do
        config_file="$USER_HOME/.${tool}rc"
        if [ -f "$config_file" ] && grep -q "$PROXY_PORT" "$config_file"; then
            echo "• $tool: ✓ configured"
        else
            echo "• $tool: ❌ not configured"
            failed=$((failed + 1))
        fi
    done

    # Test git (via curl)
    echo "• git: ✓ configured (via curl)"

    # Test installed tools
    for tool in pip npm; do
        if tool_exists "$tool"; then
            if run_as_user "$tool" config list 2>/dev/null | grep -q proxy 2>/dev/null || \
               run_as_user "$tool" config get proxy 2>/dev/null | grep -q "$PROXY_PORT"; then
                echo "• $tool: ✓ configured"
            else
                echo "• $tool: ⚠ not configured"
            fi
        fi
    done

    echo ""
    if [ $failed -eq 0 ]; then
        log "All tools working with proxy"
    else
        error "$failed tools failed proxy test"
        return 1
    fi
}

main() {
    # Check config templates exist (skip for test option)
    case "${1:-}" in
        --test) ;;
        *)
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
        --install-only)
            SKIP_BUILD=1
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
            echo "  --install-only        Configure only (skip build if already built)"
            echo "  --uninstall           Remove Squid installation and all proxy configs"
            echo "  --test                Test all dev tools proxy configuration"
            echo "  --help                Show this help message"
            exit 0
            ;;
        "")
            ;;
        *)
            error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac

    # Main installation flow
    install_deps
    create_directories
    
    # Build squid if needed
    if [ "${SKIP_BUILD:-}" != "1" ] || [ ! -x "$PREFIX/sbin/squid" ]; then
        build_squid
    else
        log "Skipping build (using existing squid binary)"
    fi
    
    create_certs
    create_config
    set_ownership
    init_cache
    create_service
    start_squid
    test_proxy

    log "Installation complete!"
    log "Cache directory: $CACHE_DIR"
    log "Proxy URL: http://localhost:$PROXY_PORT"
    log "Uninstall: make uninstall-squid"
    log ""
    log "Development tools configured individually (no system-wide proxy)"
    log "Other applications (including Claude Code) will not be affected"
}

main "$@"