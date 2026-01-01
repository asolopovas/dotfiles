#!/bin/bash

# Docker Registry Cache Installation Script
# This script sets up Docker proxy configuration and a pull-through registry cache

set -euo pipefail

# Configuration
CACHE_DIR="/mnt/d/.cache/docker-registry"
PROXY_PORT="${PROXY_PORT:-3128}"
REGISTRY_PORT="${REGISTRY_PORT:-5000}"
USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)

# Helper functions
log() { echo "✓ $*"; }
error() { echo "✗ $*" >&2; }
run_as_user() { sudo -u "$SUDO_USER" -i "$@"; }

create_config_file() {
    local tool="$1" config_path="$2" content="$3"
    run_as_user mkdir -p "$(dirname "$config_path")" 2>/dev/null || true
    [ -f "$config_path" ] && run_as_user cp "$config_path" "$config_path.bak" 2>/dev/null || true
    echo "$content" | run_as_user tee "$config_path" > /dev/null 2>&1
}

configure_docker_client() {
    log "Configuring Docker client proxy..."
    local proxy_url="http://localhost:$PROXY_PORT"
    local no_proxy="localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
    
    # Ensure Docker directory exists
    if ! run_as_user mkdir -p "$USER_HOME/.docker" 2>/dev/null; then
        error "Could not create Docker config directory"
        return 1
    fi
    
    # Create Docker client proxy configuration
    if create_config_file "Docker client" "$USER_HOME/.docker/config.json" "{
  \"proxies\": {
    \"default\": {
      \"httpProxy\": \"$proxy_url\",
      \"httpsProxy\": \"$proxy_url\",
      \"noProxy\": \"$no_proxy\"
    }
  }
}"; then
        # Verify the configuration was written correctly
        if run_as_user test -f "$USER_HOME/.docker/config.json" && \
           run_as_user grep -q "proxies" "$USER_HOME/.docker/config.json" 2>/dev/null; then
            log "Docker client proxy configuration verified"
        else
            error "Warning: Docker client configuration may not be correct"
        fi
    else
        error "Failed to create Docker client configuration"
        return 1
    fi
}

configure_docker_daemon() {
    log "Configuring Docker daemon proxy..."
    local proxy_url="http://localhost:$PROXY_PORT"
    local no_proxy="localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
    
    if command -v docker > /dev/null 2>&1; then
        # Docker daemon configuration
        if [ -w /etc/systemd/system/docker.service.d ] || mkdir -p /etc/systemd/system/docker.service.d 2>/dev/null; then
            cat > /etc/systemd/system/docker.service.d/http-proxy.conf << EOF
[Service]
Environment="HTTP_PROXY=$proxy_url"
Environment="HTTPS_PROXY=$proxy_url"
Environment="NO_PROXY=$no_proxy"
EOF
            systemctl daemon-reload > /dev/null 2>&1
            # Restart Docker daemon to apply proxy configuration
            if systemctl is-active docker >/dev/null 2>&1; then
                systemctl restart docker >/dev/null 2>&1 || true
                log "Docker daemon restarted with proxy configuration"
            else
                log "Docker daemon proxy configured (not running)"
            fi
        fi
    else
        error "Docker not found"
        return 1
    fi
}

install_docker_certificates() {
    log "Installing Docker SSL certificates..."
    local ssl_dir="/usr/local/squid/etc/ssl_cert"
    
    if [ ! -f "$ssl_dir/ca.pem" ]; then
        error "Squid CA certificate not found. Install Squid first."
        return 1
    fi
    
    # Install CA certificate for Docker registry
    mkdir -p /etc/docker/certs.d/registry-1.docker.io/
    cp "$ssl_dir/ca.pem" /etc/docker/certs.d/registry-1.docker.io/ca.crt
    
    mkdir -p /etc/docker/certs.d/auth.docker.io/
    cp "$ssl_dir/ca.pem" /etc/docker/certs.d/auth.docker.io/ca.crt
    
    mkdir -p /etc/docker/certs.d/production.cloudflare.docker.com/
    cp "$ssl_dir/ca.pem" /etc/docker/certs.d/production.cloudflare.docker.com/ca.crt
    
    log "Docker SSL certificates installed"
}

install_registry_cache() {
    log "Installing Docker registry cache..."
    
    # Create cache directory
    mkdir -p "$CACHE_DIR"
    chown "$SUDO_USER:$SUDO_USER" "$CACHE_DIR"
    
    # Stop existing registry cache if running
    if docker container ls -a --format '{{.Names}}' | grep -q '^registry-cache$'; then
        docker container stop registry-cache 2>/dev/null || true
        docker container rm registry-cache 2>/dev/null || true
        log "Removed existing registry cache container"
    fi
    
    # Start registry cache container
    docker run -d \
        --name registry-cache \
        --restart=always \
        -p "$REGISTRY_PORT:5000" \
        -v "$CACHE_DIR:/var/lib/registry" \
        -e REGISTRY_PROXY_REMOTEURL=https://registry-1.docker.io \
        registry:2
    
    log "Docker registry cache started on port $REGISTRY_PORT"
    log "Cache storage: $CACHE_DIR"
    log "Usage: docker pull localhost:$REGISTRY_PORT/library/image:tag"
}

test_configuration() {
    log "Testing Docker configuration..."
    
    # Test Docker daemon
    if ! systemctl is-active docker >/dev/null 2>&1; then
        error "Docker daemon is not running"
        return 1
    fi
    
    # Test registry cache
    if ! docker container ls --format '{{.Names}}' | grep -q '^registry-cache$'; then
        error "Registry cache container is not running"
        return 1
    fi
    
    # Test proxy configuration
    if [ -f "$USER_HOME/.docker/config.json" ] && grep -q "$PROXY_PORT" "$USER_HOME/.docker/config.json" 2>/dev/null; then
        log "Docker client proxy configured"
    else
        error "Docker client proxy not configured"
    fi
    
    if [ -f /etc/systemd/system/docker.service.d/http-proxy.conf ]; then
        log "Docker daemon proxy configured"
    else
        error "Docker daemon proxy not configured"
    fi
    
    log "Testing registry cache connectivity..."
    local response=$(curl -s "http://localhost:$REGISTRY_PORT/v2/" 2>/dev/null)
    if [ -n "$response" ]; then
        log "Registry cache is accessible"
    else
        error "Registry cache is not accessible"
        return 1
    fi
    
    log "Docker configuration test completed successfully"
}

uninstall_docker_config() {
    log "Removing Docker proxy configuration..."
    
    # Remove Docker client proxy configuration
    if [ -f "$USER_HOME/.docker/config.json" ]; then
        run_as_user cp "$USER_HOME/.docker/config.json" "$USER_HOME/.docker/config.json.bak" 2>/dev/null || true
        if command -v jq >/dev/null 2>&1; then
            run_as_user jq 'del(.proxies)' "$USER_HOME/.docker/config.json" > "$USER_HOME/.docker/config.json.tmp" 2>/dev/null || true
            run_as_user mv "$USER_HOME/.docker/config.json.tmp" "$USER_HOME/.docker/config.json" 2>/dev/null || true
        else
            if grep -q '"proxies"' "$USER_HOME/.docker/config.json" 2>/dev/null; then
                run_as_user rm -f "$USER_HOME/.docker/config.json" 2>/dev/null || true
                log "Docker client config removed"
            fi
        fi
        log "Docker client proxy configuration removed"
    fi
    
    # Remove Docker daemon proxy configuration
    if [ -f /etc/systemd/system/docker.service.d/http-proxy.conf ]; then
        rm -f /etc/systemd/system/docker.service.d/http-proxy.conf
        rmdir /etc/systemd/system/docker.service.d 2>/dev/null || true
        if command -v docker >/dev/null 2>&1; then
            systemctl daemon-reload
            systemctl restart docker 2>/dev/null || true
            log "Docker daemon proxy configuration removed"
        fi
    fi
    
    # Stop and remove registry cache
    if docker container ls -a --format '{{.Names}}' | grep -q '^registry-cache$'; then
        docker container stop registry-cache 2>/dev/null || true
        docker container rm registry-cache 2>/dev/null || true
        log "Registry cache container removed"
    fi
    
    log "Docker configuration cleanup completed"
}

show_usage() {
    echo "Docker Registry Cache Installation Script"
    echo
    echo "Usage: $0 [install|uninstall|test]"
    echo
    echo "Commands:"
    echo "  install    - Install Docker proxy configuration and registry cache"
    echo "  uninstall  - Remove Docker proxy configuration and registry cache"
    echo "  test       - Test Docker configuration"
    echo
    echo "Environment Variables:"
    echo "  PROXY_PORT     - Squid proxy port (default: 3128)"
    echo "  REGISTRY_PORT  - Registry cache port (default: 5000)"
    echo
    echo "Usage Examples:"
    echo "  # Regular Docker pulls (through Squid proxy)"
    echo "  docker pull ubuntu:20.04"
    echo
    echo "  # Cached Docker pulls (10-20x faster)"
    echo "  docker pull localhost:5000/library/ubuntu:20.04"
    echo
    echo "Cache storage: $CACHE_DIR"
}

main() {
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root"
        exit 1
    fi
    
    if [ -z "${SUDO_USER:-}" ]; then
        error "This script must be run with sudo"
        exit 1
    fi
    
    case "${1:-install}" in
        install)
            log "Installing Docker registry cache and proxy configuration..."
            configure_docker_client
            configure_docker_daemon
            install_docker_certificates
            install_registry_cache
            test_configuration
            log "Installation complete!"
            echo
            echo "Usage:"
            echo "  Regular pulls:  docker pull image:tag"
            echo "  Cached pulls:   docker pull localhost:$REGISTRY_PORT/library/image:tag"
            echo "  Cache storage:  $CACHE_DIR"
            ;;
        uninstall)
            uninstall_docker_config
            log "Uninstall complete!"
            ;;
        test)
            test_configuration
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            error "Unknown command: $1"
            show_usage
            exit 1
            ;;
    esac
}

main "$@"