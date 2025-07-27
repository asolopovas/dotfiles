#!/bin/bash
set -euo pipefail

# Proxy configuration script for all development tools
PROXY_HOST="${PROXY_HOST:-localhost}"
PROXY_PORT="${PROXY_PORT:-3128}"
PROXY_URL="http://${PROXY_HOST}:${PROXY_PORT}"
NO_PROXY="localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"

log() { echo "✓ $*"; }
error() { echo "❌ $*" >&2; }
info() { echo "ℹ️  $*"; }

# Configure Git
configure_git() {
    log "Configuring Git proxy..."
    git config --global http.proxy "$PROXY_URL"
    git config --global https.proxy "$PROXY_URL"
    git config --global http.sslVerify true
    # For git protocol (git://)
    git config --global core.gitproxy "connect -H ${PROXY_HOST}:${PROXY_PORT} %h %p"
    log "Git proxy configured"
}

# Configure pip/Python
configure_pip() {
    log "Configuring pip proxy..."
    mkdir -p ~/.config/pip
    cat > ~/.config/pip/pip.conf << EOF
[global]
proxy = $PROXY_URL
trusted-host = pypi.org pypi.python.org files.pythonhosted.org
EOF
    # Also set for legacy location
    mkdir -p ~/.pip
    cp ~/.config/pip/pip.conf ~/.pip/pip.conf
    log "pip proxy configured"
}

# Configure npm/yarn
configure_npm() {
    if command -v npm &> /dev/null; then
        log "Configuring npm proxy..."
        npm config set proxy "$PROXY_URL"
        npm config set https-proxy "$PROXY_URL"
        npm config set registry "https://registry.npmjs.org/"
        log "npm proxy configured"
    fi
    
    if command -v yarn &> /dev/null; then
        log "Configuring yarn proxy..."
        yarn config set proxy "$PROXY_URL"
        yarn config set https-proxy "$PROXY_URL"
        log "yarn proxy configured"
    fi
}

# Configure wget
configure_wget() {
    log "Configuring wget proxy..."
    cat > ~/.wgetrc << EOF
use_proxy = yes
http_proxy = $PROXY_URL
https_proxy = $PROXY_URL
no_proxy = $NO_PROXY
EOF
    log "wget proxy configured"
}

# Configure curl
configure_curl() {
    log "Configuring curl proxy..."
    cat > ~/.curlrc << EOF
proxy = "$PROXY_URL"
noproxy = "$NO_PROXY"
EOF
    log "curl proxy configured"
}

# Configure Docker
configure_docker() {
    if command -v docker &> /dev/null; then
        log "Configuring Docker proxy..."
        mkdir -p ~/.docker
        
        # Client configuration
        if [ -f ~/.docker/config.json ]; then
            # Backup existing config
            cp ~/.docker/config.json ~/.docker/config.json.bak
        fi
        
        cat > ~/.docker/config.json << EOF
{
  "proxies": {
    "default": {
      "httpProxy": "$PROXY_URL",
      "httpsProxy": "$PROXY_URL",
      "noProxy": "$NO_PROXY"
    }
  }
}
EOF
        
        # Daemon configuration (requires sudo)
        if [ -w /etc/systemd/system/docker.service.d ] || sudo -n true 2>/dev/null; then
            sudo mkdir -p /etc/systemd/system/docker.service.d
            sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf > /dev/null << EOF
[Service]
Environment="HTTP_PROXY=$PROXY_URL"
Environment="HTTPS_PROXY=$PROXY_URL"
Environment="NO_PROXY=$NO_PROXY"
EOF
            sudo systemctl daemon-reload
            info "Docker daemon proxy configured (restart Docker to apply)"
        else
            info "Skipping Docker daemon config (requires sudo)"
        fi
        log "Docker client proxy configured"
    fi
}

# Configure Cargo/Rust
configure_cargo() {
    if command -v cargo &> /dev/null; then
        log "Configuring Cargo proxy..."
        mkdir -p ~/.cargo
        if [ -f ~/.cargo/config.toml ]; then
            cp ~/.cargo/config.toml ~/.cargo/config.toml.bak
        fi
        cat >> ~/.cargo/config.toml << EOF

[http]
proxy = "$PROXY_URL"

[https]
proxy = "$PROXY_URL"
EOF
        log "Cargo proxy configured"
    fi
}

# Configure Go
configure_go() {
    if command -v go &> /dev/null; then
        log "Configuring Go proxy..."
        go env -w HTTP_PROXY="$PROXY_URL"
        go env -w HTTPS_PROXY="$PROXY_URL"
        go env -w NO_PROXY="$NO_PROXY"
        log "Go proxy configured"
    fi
}

# Configure Gradle
configure_gradle() {
    if [ -d ~/.gradle ] || command -v gradle &> /dev/null; then
        log "Configuring Gradle proxy..."
        mkdir -p ~/.gradle
        cat > ~/.gradle/gradle.properties << EOF
systemProp.http.proxyHost=$PROXY_HOST
systemProp.http.proxyPort=$PROXY_PORT
systemProp.https.proxyHost=$PROXY_HOST
systemProp.https.proxyPort=$PROXY_PORT
systemProp.http.nonProxyHosts=$NO_PROXY
systemProp.https.nonProxyHosts=$NO_PROXY
EOF
        log "Gradle proxy configured"
    fi
}

# Configure Maven
configure_maven() {
    if command -v mvn &> /dev/null || [ -d ~/.m2 ]; then
        log "Configuring Maven proxy..."
        mkdir -p ~/.m2
        cat > ~/.m2/settings.xml << EOF
<settings>
  <proxies>
    <proxy>
      <id>http-proxy</id>
      <active>true</active>
      <protocol>http</protocol>
      <host>$PROXY_HOST</host>
      <port>$PROXY_PORT</port>
      <nonProxyHosts>$NO_PROXY</nonProxyHosts>
    </proxy>
    <proxy>
      <id>https-proxy</id>
      <active>true</active>
      <protocol>https</protocol>
      <host>$PROXY_HOST</host>
      <port>$PROXY_PORT</port>
      <nonProxyHosts>$NO_PROXY</nonProxyHosts>
    </proxy>
  </proxies>
</settings>
EOF
        log "Maven proxy configured"
    fi
}

# Configure HuggingFace
configure_huggingface() {
    log "Configuring HuggingFace proxy..."
    mkdir -p ~/.cache/huggingface
    # HuggingFace uses standard HTTP(S)_PROXY env vars
    # But we can also set it in Python startup
    mkdir -p ~/.ipython/profile_default/startup
    cat > ~/.ipython/profile_default/startup/00-proxy.py << EOF
import os
os.environ['HTTP_PROXY'] = '$PROXY_URL'
os.environ['HTTPS_PROXY'] = '$PROXY_URL'
os.environ['NO_PROXY'] = '$NO_PROXY'
EOF
    log "HuggingFace proxy configured (via environment)"
}

# Configure apt
configure_apt() {
    if command -v apt &> /dev/null && ([ -w /etc/apt ] || sudo -n true 2>/dev/null); then
        log "Configuring apt proxy..."
        echo "Acquire::http::Proxy \"$PROXY_URL\";" | sudo tee /etc/apt/apt.conf.d/99proxy > /dev/null
        echo "Acquire::https::Proxy \"$PROXY_URL\";" | sudo tee -a /etc/apt/apt.conf.d/99proxy > /dev/null
        log "apt proxy configured"
    fi
}

# Configure snap
configure_snap() {
    if command -v snap &> /dev/null && sudo -n true 2>/dev/null; then
        log "Configuring snap proxy..."
        sudo snap set system proxy.http="$PROXY_URL"
        sudo snap set system proxy.https="$PROXY_URL"
        log "snap proxy configured"
    fi
}

# Update shell profile
update_profile() {
    log "Updating shell profile..."
    profile_file="$HOME/.profile"
    
    # Check if proxy settings already exist
    if ! grep -q "HTTP_PROXY.*3128" "$profile_file"; then
        cat >> "$profile_file" << EOF

# Proxy settings (added by configure-dev-tools-proxy.sh)
export HTTP_PROXY=$PROXY_URL
export HTTPS_PROXY=$PROXY_URL
export http_proxy=$PROXY_URL
export https_proxy=$PROXY_URL
export NO_PROXY=$NO_PROXY
export no_proxy=$NO_PROXY
EOF
        log "Shell profile updated"
    else
        log "Shell profile already has proxy settings"
    fi
}

# Main function
main() {
    echo "=== Configuring proxy for all development tools ==="
    echo "Proxy URL: $PROXY_URL"
    echo ""
    
    # Check if proxy is accessible
    if ! timeout 5 curl -s --proxy "$PROXY_URL" --connect-timeout 3 http://httpbin.org/get > /dev/null 2>&1; then
        error "Cannot connect to proxy at $PROXY_URL"
        error "Please ensure Squid is running: sudo systemctl start squid"
        exit 1
    fi
    
    # Configure all tools
    configure_git
    configure_pip
    configure_npm
    configure_wget
    configure_curl
    configure_docker
    configure_cargo
    configure_go
    configure_gradle
    configure_maven
    configure_huggingface
    configure_apt
    configure_snap
    update_profile
    
    echo ""
    log "All development tools configured to use proxy!"
    info "You may need to restart your shell or source ~/.profile for environment changes"
    info "Some tools may require application restart to pick up proxy settings"
}

# Handle command line options
case "${1:-}" in
    --remove|--disable)
        echo "Removing proxy configurations..."
        git config --global --unset http.proxy 2>/dev/null || true
        git config --global --unset https.proxy 2>/dev/null || true
        npm config delete proxy 2>/dev/null || true
        npm config delete https-proxy 2>/dev/null || true
        rm -f ~/.wgetrc ~/.curlrc ~/.pip/pip.conf ~/.config/pip/pip.conf
        rm -f ~/.docker/config.json
        sudo rm -f /etc/apt/apt.conf.d/99proxy 2>/dev/null || true
        log "Proxy configurations removed"
        ;;
    *)
        main
        ;;
esac