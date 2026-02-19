#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Docker test runner — three-layer image strategy:
#
#   dotfiles-base          Heavy deps + mock Plesk env (built once, cached)
#   dotfiles-bootstrapped  Base + both bootstraps done (stduser + plesk)
#                          Created by 'make test-bootstrap', committed as image.
#
# Workflow:
#   make test-bootstrap    Run init.sh for both users, commit snapshot (~5min)
#   make test              Run bats from snapshot (<30s). Auto-bootstraps if needed.
#   make test-init-shell   Debug shell in bootstrapped container
#   make test-init-clean   Remove all images
#
# The key insight: bootstrapping (downloading bun/deno/nvim/node) is slow
# and only needs to run once. Subsequent 'make test' runs mount the latest
# test files and run bats against the already-installed state.
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BASE_IMAGE="dotfiles-base"
BOOT_IMAGE="dotfiles-bootstrapped"
CONTAINER="dotfiles-test-run"

log()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
err()  { printf '\033[0;31m%s\033[0m\n' "$*" >&2; }
info() { printf '\033[0;33m%s\033[0m\n' "$*"; }

require_docker() {
    command -v docker &>/dev/null || { err "Docker required."; exit 1; }
    docker info &>/dev/null 2>&1  || { err "Docker daemon not running."; exit 1; }
}

build_base() {
    if docker image inspect "$BASE_IMAGE" &>/dev/null; then
        info "Base image cached."
        return 0
    fi
    log "Building base image (first time, will be cached)..."
    docker build -f "$SCRIPT_DIR/Dockerfile.base" -t "$BASE_IMAGE" "$REPO_DIR"
}

# Run both bootstraps inside a container, then commit as dotfiles-bootstrapped
do_bootstrap() {
    build_base

    # Build thin entrypoint image (temporary, for bootstrap only)
    local tmp_image="dotfiles-bootstrap-runner"
    docker build -f "$SCRIPT_DIR/Dockerfile.init-test" -t "$tmp_image" "$REPO_DIR"

    log "Running bootstrap (stduser + plesk)..."
    docker rm -f "$CONTAINER" 2>/dev/null || true
    docker run --name "$CONTAINER" \
        -v "$REPO_DIR:/mnt/dotfiles:ro" \
        "$tmp_image" bootstrap

    log "Committing bootstrapped snapshot..."
    docker commit "$CONTAINER" "$BOOT_IMAGE"
    docker rm -f "$CONTAINER" 2>/dev/null || true
    docker rmi -f "$tmp_image" 2>/dev/null || true

    log "Snapshot saved as $BOOT_IMAGE"
}

# Run bats suites from the bootstrapped snapshot
do_test() {
    if ! docker image inspect "$BOOT_IMAGE" &>/dev/null; then
        info "No bootstrap snapshot found. Running bootstrap first..."
        do_bootstrap
    fi

    log "Running bats tests..."
    docker rm -f "$CONTAINER" 2>/dev/null || true
    docker run --name "$CONTAINER" --rm \
        -v "$REPO_DIR:/mnt/dotfiles:ro" \
        --entrypoint /entrypoint.sh \
        "$BOOT_IMAGE" test
}

do_shell() {
    if ! docker image inspect "$BOOT_IMAGE" &>/dev/null; then
        info "No bootstrap snapshot found. Running bootstrap first..."
        do_bootstrap
    fi

    docker rm -f "$CONTAINER" 2>/dev/null || true
    docker run --name "$CONTAINER" --rm -it \
        -v "$REPO_DIR:/mnt/dotfiles:ro" \
        --entrypoint /entrypoint.sh \
        "$BOOT_IMAGE" shell
}

do_clean() {
    log "Cleaning..."
    docker rm -f "$CONTAINER" 2>/dev/null || true
    docker rmi -f "$BOOT_IMAGE" "$BASE_IMAGE" "dotfiles-bootstrap-runner" \
        "dotfiles-init-test" 2>/dev/null || true
    log "Done"
}

require_docker

case "${1:-}" in
    clean)     do_clean ;;
    bootstrap) do_bootstrap ;;
    rebuild)   do_clean; do_bootstrap; do_test ;;
    shell)     do_shell ;;
    *)         do_test ;;
esac
