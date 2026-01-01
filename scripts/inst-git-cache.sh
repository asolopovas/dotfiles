#!/bin/bash
set -euo pipefail

CACHE_DIR="/mnt/d/.cache/git"
log() { echo -e "\033[0;32m✓\033[0m $1"; }
error() { echo -e "\033[0;31m✗\033[0m $1" >&2; }
run_as_user() { [ -n "${SUDO_USER:-}" ] && sudo -u "$SUDO_USER" "$@" || "$@"; }

install_git_cache() {
    mkdir -p "$CACHE_DIR" && chown "$SUDO_USER:$SUDO_USER" "$CACHE_DIR"
    run_as_user mkdir -p "/home/$SUDO_USER/.local/bin"
    run_as_user wget -q "https://github.com/seeraven/gitcache/releases/download/v1.0.28/gitcache_v1.0.28_Ubuntu22.04_x86_64" -O "/home/$SUDO_USER/.local/bin/gitcache"
    run_as_user chmod +x "/home/$SUDO_USER/.local/bin/gitcache"
    
    # Set cache directory via environment variable
    run_as_user bash -c "echo 'export GITCACHE_DIR=\"$CACHE_DIR\"' >> /home/$SUDO_USER/.bashrc"
    
    # Initialize gitcache with proper cache directory
    run_as_user env GITCACHE_DIR="$CACHE_DIR" "/home/$SUDO_USER/.local/bin/gitcache" --help >/dev/null 2>&1 || true
    
    log "Gitcache installed"
}

configure_git_client() {
    run_as_user ln -sf "/home/$SUDO_USER/.local/bin/gitcache" "/home/$SUDO_USER/.local/bin/git"
    log "Git configured"
}

test_git_cache() {
    [ ! -f "/home/$SUDO_USER/.local/bin/gitcache" ] && { error "Gitcache not installed"; return 1; }
    
    local test_dir="/tmp/git-cache-test-$$"
    mkdir -p "$test_dir" && cd "$test_dir"
    
    local start_time=$(date +%s.%N)
    run_as_user env GITCACHE_DIR="$CACHE_DIR" PATH="/home/$SUDO_USER/.local/bin:$PATH" git clone --depth 1 https://github.com/laravel/laravel.git test1 >/dev/null 2>&1
    local duration=$(echo "$(date +%s.%N) - $start_time" | bc)
    
    rm -rf test1 && sleep 1
    start_time=$(date +%s.%N)
    run_as_user env GITCACHE_DIR="$CACHE_DIR" PATH="/home/$SUDO_USER/.local/bin:$PATH" git clone --depth 1 https://github.com/laravel/laravel.git test1 >/dev/null 2>&1
    local cached_duration=$(echo "$(date +%s.%N) - $start_time" | bc)
    
    local speedup=$(echo "scale=1; $duration / $cached_duration" | bc)
    log "Performance: ${speedup}x faster with cache"
    
    cd - >/dev/null && rm -rf "$test_dir"
}

uninstall_git_cache() {
    run_as_user rm -f "/home/$SUDO_USER/.local/bin/gitcache" "/home/$SUDO_USER/.local/bin/git"
    run_as_user sed -i '/export GITCACHE_DIR=/d' "/home/$SUDO_USER/.bashrc" 2>/dev/null || true
    log "Gitcache removed"
}

case "${1:-install}" in
    install) install_git_cache && configure_git_client && test_git_cache && log "Git cache active" ;;
    test) test_git_cache ;;
    uninstall) uninstall_git_cache ;;
    *) error "Usage: $0 {install|test|uninstall}"; exit 1 ;;
esac