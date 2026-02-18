#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Runs full init.sh + plesk-init.sh deployment tests inside Docker.
#
# Usage:
#   ./tests/run-init-tests.sh           Build image + run tests
#   ./tests/run-init-tests.sh build     Build image only
#   ./tests/run-init-tests.sh shell     Drop into container for debugging
#   ./tests/run-init-tests.sh clean     Remove image and build cache
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
IMAGE_NAME="dotfiles-init-test"
CONTAINER_NAME="dotfiles-init-test-run"

log() { printf '\033[0;32m%s\033[0m\n' "$*"; }
err() { printf '\033[31m%s\033[0m\n' "$*" >&2; }

require_docker() {
    if ! command -v docker &>/dev/null; then
        err "Docker is required. Install it first."
        exit 1
    fi
    if ! docker info &>/dev/null 2>&1; then
        err "Docker daemon not running."
        exit 1
    fi
}

build_image() {
    log "Building test image..."
    docker build \
        -f "$SCRIPT_DIR/Dockerfile.init-test" \
        -t "$IMAGE_NAME" \
        "$REPO_DIR"
}

# Bootstrap script run inside the container.
# Simulates: bash -c "$(curl -fsSL .../init.sh)"
read -r -d '' CONTAINER_SCRIPT << 'INNER' || true
set -euo pipefail

# Copy repo files (mount is read-only)
cp -a /mnt/dotfiles /root/dotfiles

# init.sh expects ~/dotfiles to either not exist (clone) or be a git repo
# (fetch+reset). Create a minimal git repo so the update path succeeds.
cd /root/dotfiles
git init -q
git add -A
git -c user.name=test -c user.email=test@test commit -q -m "init" --allow-empty

# Run the full bootstrap
export CHANGE_SHELL=false
bash /root/dotfiles/init.sh

# Run bats tests
bats /root/dotfiles/tests/test-init.bats --tap
INNER

run_tests() {
    log "Running init deployment tests..."
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

    docker run \
        --name "$CONTAINER_NAME" \
        --rm \
        -v "$REPO_DIR:/mnt/dotfiles:ro" \
        "$IMAGE_NAME" \
        bash -c "$CONTAINER_SCRIPT"

    local rc=$?
    if [ $rc -eq 0 ]; then
        log "All tests passed!"
    else
        err "Tests failed (exit $rc)"
    fi
    return $rc
}

run_shell() {
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
    log "Dropping into test container shell..."
    docker run \
        --name "$CONTAINER_NAME" \
        --rm -it \
        -v "$REPO_DIR:/mnt/dotfiles:ro" \
        "$IMAGE_NAME" \
        bash -c '
            cp -a /mnt/dotfiles /root/dotfiles
            cd /root/dotfiles
            git init -q && git add -A
            git -c user.name=test -c user.email=test@test commit -q -m "init" --allow-empty
            echo "Dotfiles at ~/dotfiles. Run: CHANGE_SHELL=false bash ~/dotfiles/init.sh"
            exec bash
        '
}

do_clean() {
    log "Cleaning up..."
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
    docker rmi -f "$IMAGE_NAME" 2>/dev/null || true
    log "Done"
}

require_docker

case "${1:-}" in
    build) build_image ;;
    shell) build_image; run_shell ;;
    clean) do_clean ;;
    *)     build_image; run_tests ;;
esac
