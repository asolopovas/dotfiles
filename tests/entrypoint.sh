#!/bin/bash
set -uo pipefail

# ---------------------------------------------------------------------------
# Container entrypoint — two modes:
#
#   bootstrap     Run init.sh for stduser + plesk root (no bats).
#                 Container is then committed as dotfiles-bootstrapped.
#
#   test          Run bats suites against already-bootstrapped state.
#                 Tests are bind-mounted from /mnt/dotfiles/tests.
#
#   shell         Interactive debug shell.
# ---------------------------------------------------------------------------

MODE="${1:-test}"

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
run_bootstrap() {
    local user="$1" home="$2"
    shift 2; local extra_env=("$@")

    rm -rf "$home/dotfiles"

    local init_tmp; init_tmp=$(mktemp)
    cp /mnt/dotfiles/init.sh "$init_tmp"
    chmod 644 "$init_tmp"; chown "$user:" "$init_tmp"

    echo "  Bootstrapping as $user (HOME=$home)..."
    local env_args=(HOME="$home" DOTFILES_URL="file:///srv/dotfiles.git" CHANGE_SHELL=false)
    env_args+=("${extra_env[@]}")

    local rc=0
    if [ "$user" = "root" ]; then
        env "${env_args[@]}" bash "$init_tmp" || rc=$?
    else
        sudo -u "$user" env "${env_args[@]}" bash "$init_tmp" || rc=$?
    fi
    rm -f "$init_tmp"

    if [ "$rc" -ne 0 ]; then
        fail "Bootstrap as $user exited $rc"
        return "$rc"
    fi
}

# ===========================================================================
#  MODE: bootstrap — run init.sh for both users, then exit 0 for commit
# ===========================================================================
do_bootstrap() {
    setup_local_repo

    # 1. Stduser full bootstrap (hide /etc/psa so init.sh takes normal path)
    log "BOOTSTRAP: stduser"
    [ -d /etc/psa ] && mv /etc/psa /etc/psa.hidden
    run_bootstrap stduser /home/stduser
    [ -d /etc/psa.hidden ] && mv /etc/psa.hidden /etc/psa

    # 2. Plesk root bootstrap
    log "BOOTSTRAP: plesk root"
    rm -rf /root/dotfiles /opt/dotfiles /opt/omf /opt/nvim /opt/nvim-config \
           /opt/nvim-data /opt/opencode-config /var/www/bun-cache \
           /usr/local/bin/bun* /usr/local/bin/nvim /usr/local/bin/vim \
           /etc/sudoers.d/bun-cache /etc/profile.d/bun.sh /etc/profile.d/nvim.sh
    run_bootstrap root /root

    # Marker so test mode knows bootstrap succeeded
    touch /var/tmp/.bootstrap-done

    log "BOOTSTRAP COMPLETE"
    echo "  stduser home: /home/stduser/dotfiles"
    echo "  plesk root:   /root/dotfiles"
    echo "  opt shared:   /opt/dotfiles /opt/nvim /opt/omf"
}

# ===========================================================================
#  MODE: test — sync latest test files, run bats suites
# ===========================================================================
PASS=0; FAIL=0

run_suite() {
    local name="$1" bats_file="$2" rc=0
    log "$name"
    bats "$bats_file" --tap || rc=$?
    if [ "$rc" -eq 0 ]; then
        ok "$name"; PASS=$((PASS + 1))
    else
        fail "$name"; FAIL=$((FAIL + 1))
    fi
}

sync_tests() {
    # Copy latest test files from mount into both cloned repos
    for d in /home/stduser/dotfiles /root/dotfiles; do
        [ -d "$d" ] || continue
        cp -a /mnt/dotfiles/tests "$d/tests"
    done
    [ -d /home/stduser/dotfiles/tests ] && \
        chown -R stduser: /home/stduser/dotfiles/tests
}

do_test() {
    if [ ! -f /var/tmp/.bootstrap-done ]; then
        fail "No bootstrap snapshot. Run: make test-bootstrap"
        exit 1
    fi

    sync_tests

    # Suite 1: stduser bootstrap assertions + script unit tests
    run_suite "STDUSER (bootstrap + scripts)" \
        /home/stduser/dotfiles/tests/test-stduser.bats

    # Suite 2: plesk root assertions
    run_suite "PLESK ROOT (plesk-init.sh)" \
        /root/dotfiles/tests/test-plesk.bats

    # Suite 3: vhost per-user assertions
    if [ -d /opt/dotfiles ]; then
        run_suite "PLESK VHOST (per-user setup)" \
            /root/dotfiles/tests/test-vhost.bats
    else
        fail "Skipping vhost: /opt/dotfiles missing"
        FAIL=$((FAIL + 1))
    fi

    # Summary
    local total=$((PASS + FAIL))
    log "SUMMARY: $PASS/$total suites passed"
    if [ "$FAIL" -gt 0 ]; then
        fail "$FAIL suite(s) failed"
        exit 1
    fi
}

# ---- Main ----
case "$MODE" in
    bootstrap) do_bootstrap ;;
    test)      do_test ;;
    shell)
        setup_local_repo
        [ -d /root/dotfiles ] || cp -a /mnt/dotfiles /root/dotfiles
        [ -d /home/stduser/dotfiles ] || {
            cp -a /mnt/dotfiles /home/stduser/dotfiles
            chown -R stduser: /home/stduser/dotfiles
        }
        echo "  Bootstrap: DOTFILES_URL=file:///srv/dotfiles.git CHANGE_SHELL=false bash init.sh"
        exec bash ;;
    *) echo "Usage: bootstrap | test | shell"; exit 1 ;;
esac
