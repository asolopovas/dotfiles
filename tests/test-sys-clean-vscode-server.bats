#!/usr/bin/env bats

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="$REPO_DIR/scripts/sys/sys-clean-vscode-server"

setup() {
    TMPDIR="$(mktemp -d)"
    export TMPDIR
    export PROC="$TMPDIR/proc"
    export RUN="$TMPDIR/run"
    export FAKE_BIN="$TMPDIR/bin"
    export AGE_FILE="$TMPDIR/ages"
    export CHILD_FILE="$TMPDIR/children"
    export ESTAB_FILE="$TMPDIR/estab"
    export LOGINCTL_FILE="$TMPDIR/loginctl"
    export KILL_LOG="$TMPDIR/kills"
    mkdir -p "$PROC" "$RUN" "$FAKE_BIN"
    : >"$AGE_FILE"; : >"$CHILD_FILE"; : >"$ESTAB_FILE"; : >"$LOGINCTL_FILE"; : >"$KILL_LOG"
    export PATH="$FAKE_BIN:$PATH"
    export KILL="fake-kill"
    export SLEEP="fake-sleep"

    cat >"$FAKE_BIN/ps" <<'EOF'
#!/usr/bin/env bash
pid=""
while (($#)); do [[ $1 == -p ]] && { pid=$2; shift 2; continue; }; shift; done
awk -v p="$pid" '$1==p{print $2}' "$AGE_FILE"
EOF
    cat >"$FAKE_BIN/pgrep" <<'EOF'
#!/usr/bin/env bash
if [[ $1 == -P ]]; then awk -v p="$2" '$1==p{print $2}' "$CHILD_FILE"; exit 0; fi
if [[ $1 == -u ]]; then [[ ${ACTIVE_PGREP_USER:-} == "$2" ]] && exit 0 || exit 1; fi
exit 1
EOF
    cat >"$FAKE_BIN/ss" <<'EOF'
#!/usr/bin/env bash
cat "$ESTAB_FILE"
EOF
    cat >"$FAKE_BIN/loginctl" <<'EOF'
#!/usr/bin/env bash
[[ $1 == list-sessions ]] && cat "$LOGINCTL_FILE"
EOF
    cat >"$FAKE_BIN/fake-kill" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$KILL_LOG"
EOF
    printf '#!/usr/bin/env bash\n:\n' >"$FAKE_BIN/fake-sleep"
    chmod +x "$FAKE_BIN"/*
}

teardown() { rm -rf "$TMPDIR"; }

proc_add() {
    local pid="$1" ppid="$2" comm="$3" cmd="$4"
    mkdir -p "$PROC/$pid"
    printf 'PPid:\t%s\n' "$ppid" >"$PROC/$pid/status"
    printf '%s\n' "$comm" >"$PROC/$pid/comm"
    printf '%s\0' "$cmd" >"$PROC/$pid/cmdline"
}

age_set() { printf '%s %s\n' "$1" "$2" >>"$AGE_FILE"; }
child_add() { printf '%s %s\n' "$1" "$2" >>"$CHILD_FILE"; }

@test "dry-run reports stale VS Code server without killing" {
    proc_add 100 1 code-deadbeef "/home/u/.vscode-server/code-deadbeef1234567890 --cli-data-dir x agent host"
    age_set 100 90000
    run "$SCRIPT" --dry-run --age-hours 12
    [[ $status -eq 0 ]]
    [[ $output == *"dry-run stale vscode pid=100"* ]]
    [[ ! -s $KILL_LOG ]]
}

@test "kill mode terminates stale VS Code server" {
    proc_add 101 1 code-deadbeef "/home/u/.vscode-server/code-deadbeef1234567890 --cli-data-dir x agent host"
    age_set 101 90000
    run "$SCRIPT" --kill --age-hours 12
    [[ $status -eq 0 ]]
    [[ $output == *"kill stale vscode pid=101"* ]]
    grep -q -- '-TERM 101' "$KILL_LOG"
    grep -q -- '-KILL 101' "$KILL_LOG"
}

@test "connected VS Code server is skipped" {
    proc_add 102 1 code-deadbeef "/home/u/.vscode-server/code-deadbeef1234567890 --cli-data-dir x agent host"
    age_set 102 90000
    printf 'ESTAB 0 0 127.0.0.1:1 127.0.0.1:2 users:(("code",pid=102,fd=1))\n' >"$ESTAB_FILE"
    run "$SCRIPT" --kill --age-hours 12
    [[ $status -eq 0 ]]
    [[ $output == *"skip connected pid=102"* ]]
    [[ ! -s $KILL_LOG ]]
}

@test "active login user is skipped" {
    proc_add 103 1 code-deadbeef "/home/u/.vscode-server/code-deadbeef1234567890 --cli-data-dir x agent host"
    age_set 103 90000
    printf '1 0 root - - active no -\n' >"$LOGINCTL_FILE"
    run "$SCRIPT" --kill --age-hours 12
    [[ $status -eq 0 ]]
    [[ $output == *"skip active-login pid=103 user=root"* ]]
    [[ ! -s $KILL_LOG ]]
}

@test "active VS Code server tree is skipped" {
    proc_add 200 1 code-deadbeef "/home/u/.vscode-server/code-deadbeef1234567890 --cli-data-dir x agent host"
    proc_add 201 200 node "/opt/vscode-server/server/out/server-main.js --start-server"
    child_add 200 201
    age_set 200 90000
    run "$SCRIPT" --kill --age-hours 12
    [[ $status -eq 0 ]]
    [[ $output == *"skip active-vscode-tree pid=200"* ]]
    [[ ! -s $KILL_LOG ]]
}

@test "tmux child is preserved when stale VS Code parent is killed" {
    proc_add 300 1 code-deadbeef "/home/u/.vscode-server/code-deadbeef1234567890 --cli-data-dir x agent host"
    proc_add 301 300 tmux "tmux new-session"
    child_add 300 301
    age_set 300 90000
    run "$SCRIPT" --kill --age-hours 12
    [[ $status -eq 0 ]]
    grep -q -- '-TERM 300' "$KILL_LOG"
    ! grep -q -- '301' "$KILL_LOG"
}

@test "install writes symlinks and cron file" {
    local sbin="$TMPDIR/sbin" cron="$TMPDIR/cron.d"
    run env SBIN="$sbin" CRON_D="$cron" "$SCRIPT" --install
    [[ $status -eq 0 ]]
    [[ -L "$sbin/sys-clean-vscode-server" ]]
    [[ -L "$sbin/cleanup-stale-vscode-server" ]]
    [[ -f "$cron/sys-clean-vscode-server" ]]
    grep -q 'AGE_HOURS=12' "$cron/sys-clean-vscode-server"
}
