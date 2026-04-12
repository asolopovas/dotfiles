#!/usr/bin/env bats

# ---------------------------------------------------------------------------
# Unit tests for mount-nas.sh — no network, no real mounts.
# Stubs: mountpoint, smbclient, sudo/mount
# ---------------------------------------------------------------------------

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="$REPO_DIR/scripts/mount-nas.sh"

setup() {
    export FAKE_HOME="$(mktemp -d)"
    export HOME="$FAKE_HOME"

    export FAKE_BIN="$(mktemp -d)"
    export PATH="$FAKE_BIN:$PATH"

    # stub smbclient — returns fake share list
    cat > "$FAKE_BIN/smbclient" <<'EOF'
#!/bin/bash
echo "Disk|Video|System default share"
echo "Disk|Public|System default share"
echo "Disk|Music|"
EOF
    chmod +x "$FAKE_BIN/smbclient"

    # stub sudo — resolves commands from FAKE_BIN first
    cat > "$FAKE_BIN/sudo" <<EOF
#!/bin/bash
cmd="\$1"; shift
if [ -x "$FAKE_BIN/\$cmd" ]; then
    "$FAKE_BIN/\$cmd" "\$@"
else
    "\$cmd" "\$@"
fi
EOF
    chmod +x "$FAKE_BIN/sudo"

    # stub mount — just creates a marker file
    cat > "$FAKE_BIN/mount" <<'EOF'
#!/bin/bash
# parse target dir from args: mount -t cifs //ip/share DIR -o ...
shift 2  # -t cifs
shift    # //ip/share
dir="$1"
touch "$dir/.mounted"
EOF
    chmod +x "$FAKE_BIN/mount"

    # stub chown — no-op
    cat > "$FAKE_BIN/chown" <<'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x "$FAKE_BIN/chown"

    # create fake /mnt/nas under FAKE_HOME and override MOUNT_POINT via env
    export MOUNT_POINT="$FAKE_HOME/mnt/nas"
    mkdir -p "$MOUNT_POINT"

    # override mountpoint to check marker after mount runs
    cat > "$FAKE_BIN/mountpoint" <<'EOF'
#!/bin/bash
# skip flags like -q
while [[ "$1" == -* ]]; do shift; done
[ -f "$1/.mounted" ]
EOF
    chmod +x "$FAKE_BIN/mountpoint"
}

teardown() {
    rm -rf "$FAKE_HOME" "$FAKE_BIN"
}

# =====================================================================
#  Credential handling
# =====================================================================

@test "mount-nas: creates credentials from argument" {
    run bash "$SCRIPT" "admin:secret123"
    [[ "$status" -eq 0 ]]
    [ -f "$FAKE_HOME/.nascredentials" ]
    run cat "$FAKE_HOME/.nascredentials"
    [[ "$output" == *"username=admin"* ]]
    [[ "$output" == *"password=secret123"* ]]
}

@test "mount-nas: credentials file has mode 600" {
    run bash "$SCRIPT" "admin:secret123"
    local perms
    perms=$(stat -c %a "$FAKE_HOME/.nascredentials")
    [[ "$perms" == "600" ]]
}

@test "mount-nas: reads credentials from naspass.txt" {
    echo "fileuser:filepass" > "$FAKE_HOME/naspass.txt"
    run bash "$SCRIPT"
    [[ "$status" -eq 0 ]]
    run cat "$FAKE_HOME/.nascredentials"
    [[ "$output" == *"username=fileuser"* ]]
    [[ "$output" == *"password=filepass"* ]]
}

@test "mount-nas: reuses existing credentials file" {
    printf "username=existing\npassword=creds\n" > "$FAKE_HOME/.nascredentials"
    chmod 600 "$FAKE_HOME/.nascredentials"
    run bash "$SCRIPT"
    [[ "$status" -eq 0 ]]
    # should not have been overwritten
    run cat "$FAKE_HOME/.nascredentials"
    [[ "$output" == *"username=existing"* ]]
}

@test "mount-nas: rejects invalid credentials format" {
    run bash "$SCRIPT" "nocolonhere"
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"Invalid credentials"* ]]
}

@test "mount-nas: fails with no credentials available" {
    # pipe empty input so read gets EOF
    run bash -c "echo '' | bash '$SCRIPT'"
    [[ "$status" -eq 1 ]]
}

# =====================================================================
#  Mounting
# =====================================================================

@test "mount-nas: mounts all discovered shares" {
    run env PATH="$FAKE_BIN:$PATH" HOME="$FAKE_HOME" MOUNT_POINT="$MOUNT_POINT" bash "$SCRIPT" "user:pass"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Video: mounted"* ]]
    [[ "$output" == *"Public: mounted"* ]]
    [[ "$output" == *"Music: mounted"* ]]
    [[ "$output" == *"3 mounted, 0 failed"* ]]
}

@test "mount-nas: creates mount directories" {
    run bash "$SCRIPT" "user:pass"
    [ -d "$FAKE_HOME/mnt/nas/Video" ]
    [ -d "$FAKE_HOME/mnt/nas/Public" ]
    [ -d "$FAKE_HOME/mnt/nas/Music" ]
}

@test "mount-nas: reports no shares when smbclient returns nothing" {
    cat > "$FAKE_BIN/smbclient" <<'EOF'
#!/bin/bash
echo ""
EOF
    chmod +x "$FAKE_BIN/smbclient"

    run bash "$SCRIPT" "user:pass"
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"No shares found"* ]]
}

@test "mount-nas: idempotent — skips already mounted shares" {
    # First run
    bash "$SCRIPT" "user:pass"

    run bash "$SCRIPT"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"already mounted"* ]]
}
