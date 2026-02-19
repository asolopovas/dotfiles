#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Docker test runner.  Two-layer image:
#   dotfiles-base       Heavy deps + mock Plesk env (built once, cached)
#   dotfiles-init-test  Thin entrypoint (rebuilds in <1s)
#
# Usage:
#   ./tests/run-init-tests.sh              Run ALL 3 suites
#   ./tests/run-init-tests.sh stduser      Stduser bootstrap + script tests
#   ./tests/run-init-tests.sh plesk        Plesk root + vhost tests
#   ./tests/run-init-tests.sh shell        Debug shell
#   ./tests/run-init-tests.sh clean        Remove images
#   ./tests/run-init-tests.sh rebuild      Force full rebuild then test
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BASE_IMAGE="dotfiles-base"
TEST_IMAGE="dotfiles-init-test"
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
        info "Base image cached. Use 'make test-init-clean' to force rebuild."
        return 0
    fi
    log "Building base image (first time, will be cached)..."
    docker build -f "$SCRIPT_DIR/Dockerfile.base" -t "$BASE_IMAGE" "$REPO_DIR"
}

build_test() {
    log "Building test image..."
    docker build -f "$SCRIPT_DIR/Dockerfile.init-test" -t "$TEST_IMAGE" "$REPO_DIR"
}

run_container() {
    local mode="$1"
    local it_flag=""
    [[ "$mode" == "shell" ]] && it_flag="-it"

    docker rm -f "$CONTAINER" 2>/dev/null || true
    docker run --name "$CONTAINER" --rm $it_flag \
        -v "$REPO_DIR:/mnt/dotfiles:ro" \
        "$TEST_IMAGE" "$mode"
}

do_clean() {
    log "Cleaning..."
    docker rm -f "$CONTAINER" 2>/dev/null || true
    docker rmi -f "$TEST_IMAGE" "$BASE_IMAGE" 2>/dev/null || true
    log "Done"
}

require_docker

case "${1:-}" in
    clean)    do_clean ;;
    rebuild)  do_clean; build_base; build_test; run_container test-all ;;
    build)    build_base; build_test ;;
    shell)    build_base; build_test; run_container shell ;;
    stduser)  build_base; build_test; run_container test-stduser ;;
    plesk)    build_base; build_test; run_container test-plesk ;;
    *)        build_base; build_test; run_container test-all ;;
esac
