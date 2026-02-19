#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Three test suites, one container:
#
#   1. test-stduser   Full init.sh bootstrap as sudoer + script unit tests
#   2. test-plesk     init.sh -> plesk-init.sh all (root shared installs)
#   3. test-vhost     Per-vhost-user assertions (after test-plesk)
#
# Bootstrap simulates:  bash -c "$(curl -fsSL .../init.sh)"
# via a local bare repo clone instead of GitHub.
# ---------------------------------------------------------------------------

MODE="${1:-test-all}"
PASS=0; FAIL=0

log()  { printf '\n\033[1;36m========  %s  ========\033[0m\n' "$*"; }
ok()   { printf '\033[0;32m  PASS: %s\033[0m\n' "$*"; }
fail() { printf '\033[0;31m  FAIL: %s\033[0m\n' "$*" >&2; }

# ---- Bare repo simulating GitHub ----
setup_local_repo() {
    [ -d /srv/dotfiles.git ] && return
    git clone --bare /mnt/dotfiles /srv/dotfiles.git 2>/dev/null
    local head
    head=$(git -C /srv/dotfiles.git branch | head -1 | sed 's/^[* ]*//')
    [ "$head" != "main" ] && [ -n "$head" ] && \
        git -C /srv/dotfiles.git branch main "$head" 2>/dev/null || true
    git -C /srv/dotfiles.git symbolic-ref HEAD refs/heads/main 2>/dev/null || true
}

# ---- Simulate: bash -c "$(curl -fsSL .../init.sh)" ----
bootstrap() {
    local user="$1" home="$2"
    shift 2; local extra_env=("$@")

    rm -rf "$home/dotfiles"

    local init_tmp; init_tmp=$(mktemp)
    cp /mnt/dotfiles/init.sh "$init_tmp"
    chmod 644 "$init_tmp"; chown "$user:" "$init_tmp"

    echo "  Bootstrapping as $user (HOME=$home)..."
    local env_args=(HOME="$home" DOTFILES_URL="file:///srv/dotfiles.git" CHANGE_SHELL=false)
    env_args+=("${extra_env[@]}")

    if [ "$user" = "root" ]; then
        env "${env_args[@]}" bash "$init_tmp"
    else
        sudo -u "$user" env "${env_args[@]}" bash "$init_tmp"
    fi
    rm -f "$init_tmp"

    # Sync latest test files into the cloned repo
    cp -a /mnt/dotfiles/tests "$home/dotfiles/tests"
    [ "$user" != "root" ] && chown -R "$user:" "$home/dotfiles/tests"
}

run_suite() {
    local name="$1" bats_file="$2"
    log "$name"
    if bats "$bats_file" --tap; then
        ok "$name"; PASS=$((PASS + 1))
    else
        fail "$name"; FAIL=$((FAIL + 1))
    fi
}

# ==== 1. Stduser: bootstrap + script unit tests ====
do_test_stduser() {
    log "SETUP: stduser full bootstrap"
    [ -d /etc/psa ] && mv /etc/psa /etc/psa.hidden
    bootstrap stduser /home/stduser
    [ -d /etc/psa.hidden ] && mv /etc/psa.hidden /etc/psa
    run_suite "STDUSER (bootstrap + scripts)" \
        /home/stduser/dotfiles/tests/test-stduser.bats
}

# ==== 2. Plesk root: bootstrap -> plesk-init.sh ====
do_test_plesk() {
    log "SETUP: Plesk root bootstrap"
    rm -rf /root/dotfiles /opt/dotfiles /opt/omf /opt/nvim /opt/nvim-config \
           /opt/nvim-data /opt/opencode-config /var/www/bun-cache \
           /usr/local/bin/bun* /usr/local/bin/nvim /usr/local/bin/vim \
           /etc/sudoers.d/bun-cache /etc/profile.d/bun.sh /etc/profile.d/nvim.sh
    bootstrap root /root
    run_suite "PLESK ROOT (bootstrap + plesk-init.sh)" \
        /root/dotfiles/tests/test-plesk.bats
}

# ==== 3. Vhost: per-user assertions (after plesk) ====
do_test_vhost() {
    if [ ! -d /opt/dotfiles ]; then
        fail "test-vhost requires test-plesk to run first"
        FAIL=$((FAIL + 1)); return
    fi
    run_suite "PLESK VHOST (per-user setup)" \
        /root/dotfiles/tests/test-vhost.bats
}

summary() {
    local total=$((PASS + FAIL))
    log "SUMMARY: $PASS/$total suites passed"
    [ "$FAIL" -gt 0 ] && { fail "$FAIL suite(s) failed"; exit 1; }
}

# ---- Main ----
setup_local_repo

case "$MODE" in
    test-all)
        do_test_stduser
        do_test_plesk
        do_test_vhost
        summary ;;
    test-stduser) do_test_stduser; summary ;;
    test-plesk)   do_test_plesk; do_test_vhost; summary ;;
    test-vhost)   do_test_vhost; summary ;;
    shell)
        cp -a /mnt/dotfiles /root/dotfiles
        cp -a /mnt/dotfiles /home/stduser/dotfiles
        chown -R stduser: /home/stduser/dotfiles
        echo "  Bootstrap: DOTFILES_URL=file:///srv/dotfiles.git CHANGE_SHELL=false bash init.sh"
        exec bash ;;
    *) echo "Usage: test-all | test-stduser | test-plesk | test-vhost | shell"; exit 1 ;;
esac
