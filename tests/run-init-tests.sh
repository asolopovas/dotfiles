#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BASE_IMAGE="dotfiles-base"
BOOT_IMAGE="dotfiles-bootstrapped"
CONTAINER="dotfiles-test-run"

log() { printf '\033[0;32m%s\033[0m\n' "$*"; }
err() { printf '\033[0;31m%s\033[0m\n' "$*" >&2; }
info() { printf '\033[0;33m%s\033[0m\n' "$*"; }

require_docker() {
	command -v docker &>/dev/null || {
		err "Docker required."
		exit 1
	}
	docker info &>/dev/null 2>&1 || {
		err "Docker daemon not running."
		exit 1
	}
}

build_base() {
	if docker image inspect "$BASE_IMAGE" &>/dev/null; then
		info "Base image cached."
		return 0
	fi
	log "Building base image (first time, will be cached)..."
	docker build -f "$SCRIPT_DIR/Dockerfile.base" -t "$BASE_IMAGE" "$REPO_DIR"
}

do_bootstrap() {
	build_base

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

do_test() {
	if ! docker image inspect "$BOOT_IMAGE" &>/dev/null; then
		info "No bootstrap snapshot found. Running bootstrap first..."
		do_bootstrap
	fi

	log "Running bats tests..."
	docker rm -f "$CONTAINER" 2>/dev/null || true
	docker run --name "$CONTAINER" --rm \
		-v "$REPO_DIR:/mnt/dotfiles:ro" \
		-v "$SCRIPT_DIR/entrypoint.sh:/entrypoint.sh:ro" \
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
		-v "$SCRIPT_DIR/entrypoint.sh:/entrypoint.sh:ro" \
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
clean) do_clean ;;
bootstrap) do_bootstrap ;;
rebuild)
	do_clean
	do_bootstrap
	do_test
	;;
shell) do_shell ;;
*) do_test ;;
esac
