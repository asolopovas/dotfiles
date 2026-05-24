#!/usr/bin/env bats

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="$REPO_DIR/scripts/inst/inst-picom.sh"

setup() {
    FAKE_HOME="$(mktemp -d)"
    export FAKE_HOME
    TMPDIR="$(mktemp -d)"
    export TMPDIR
    export FAKE_BIN="$TMPDIR/fake-bin"
    mkdir -p "$FAKE_BIN" "$FAKE_HOME/.config" "$FAKE_HOME/.local/bin"
    cat >"$FAKE_BIN/sudo" <<'S'
#!/bin/sh
while [ $# -gt 0 ]; do case "$1" in -n|-E) shift;; -*) shift;; *) break;; esac; done
"$@"
S
    for bin in apt-get meson pkill nvidia-smi sleep; do
        printf '#!/bin/sh\nexit 0\n' >"$FAKE_BIN/$bin"
    done
    cat >"$FAKE_BIN/git" <<'G'
#!/bin/sh
if [ "$1" = clone ]; then
    for a; do target="$a"; done
    mkdir -p "$target"
fi
exit 0
G
    printf '#!/bin/sh\necho 12345\nexit 0\n' >"$FAKE_BIN/pgrep"
    cat >"$FAKE_BIN/ninja" <<N
#!/bin/sh
for a in "\$@"; do [ "\$a" = install ] && {
    cat > "$FAKE_HOME/.local/bin/picom" <<'P'
#!/bin/sh
case "\$1" in --version) echo "v13 (test)";; *) exit 0;; esac
P
    chmod +x "$FAKE_HOME/.local/bin/picom"
}; done
exit 0
N
    chmod +x "$FAKE_BIN"/*
    export HOME="$FAKE_HOME"
    export PATH="$FAKE_BIN:$PATH"
}

teardown() {
    rm -rf "$FAKE_HOME" "$TMPDIR"
}

run_script() {
    env -u FORCE -u KEEP_CONFIG -u PICOM_TAG HOME="$FAKE_HOME" PATH="$FAKE_BIN:$PATH" TMPDIR="$TMPDIR" bash "$SCRIPT"
}

plant_picom() {
    cat >"$FAKE_HOME/.local/bin/picom" <<'P'
#!/bin/sh
case "$1" in --version) echo "v13";; *) exit 0;; esac
P
    chmod +x "$FAKE_HOME/.local/bin/picom"
}

@test "picom: script exists and syntax is valid" {
    [ -x "$SCRIPT" ]
    run bash -n "$SCRIPT"
    [[ "$status" -eq 0 ]]
}

@test "picom: fresh run installs binary and writes tuned config" {
    run run_script
    [[ "$status" -eq 0 ]]
    [ -x "$FAKE_HOME/.local/bin/picom" ]
    local conf="$FAKE_HOME/.config/picom.conf"
    [ -f "$conf" ]
    grep -q '^unredir-if-possible = true' "$conf"
    grep -q '^shadow = false' "$conf"
    grep -q '^fading = false' "$conf"
    grep -q '^corner-radius = 0' "$conf"
    run grep -Eq '^(blur-method|blur-kern)' "$conf"
    [[ "$status" -ne 0 ]]
    grep -q '^backend = "glx"' "$conf"
    grep -q '^vsync = true' "$conf"
    grep -q '^xrender-sync-fence = true' "$conf"
    grep -q '^use-damage = true' "$conf"
    run grep -Eq '^glx-no-(stencil|rebind-pixmap)' "$conf"
    [[ "$status" -ne 0 ]]
    grep -q '^inactive-opacity = 1.0' "$conf"
    grep -q '^active-opacity = 1.0' "$conf"
    grep -q '^frame-opacity = 1.0' "$conf"
}

@test "picom: skips rebuild when requested tag already installed" {
    plant_picom
    run run_script
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"already installed"* ]]
    [[ "$output" != *"Cloning picom"* ]]
}

@test "picom: FORCE=true rebuilds even when already installed" {
    plant_picom
    run env FORCE=true KEEP_CONFIG=false PICOM_TAG=v13 HOME="$FAKE_HOME" PATH="$FAKE_BIN:$PATH" TMPDIR="$TMPDIR" bash "$SCRIPT"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Cloning picom"* ]]
}

@test "picom: PICOM_TAG overrides default tag" {
    run env FORCE=false KEEP_CONFIG=false PICOM_TAG=v12 HOME="$FAKE_HOME" PATH="$FAKE_BIN:$PATH" TMPDIR="$TMPDIR" bash "$SCRIPT"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"v12"* ]]
}

@test "picom: backs up existing config" {
    echo "old config" >"$FAKE_HOME/.config/picom.conf"
    run_script
    local backups=("$FAKE_HOME/.config/picom.conf.bak."*)
    [ -f "${backups[0]}" ]
    grep -q "old config" "${backups[0]}"
}

@test "picom: no backup created on fresh install" {
    run_script
    local backups=("$FAKE_HOME/.config/picom.conf.bak."*)
    [ ! -e "${backups[0]}" ]
}

@test "picom: KEEP_CONFIG=true leaves existing config untouched" {
    echo "sacred config" >"$FAKE_HOME/.config/picom.conf"
    run env FORCE=false KEEP_CONFIG=true PICOM_TAG=v13 HOME="$FAKE_HOME" PATH="$FAKE_BIN:$PATH" TMPDIR="$TMPDIR" bash "$SCRIPT"
    [[ "$status" -eq 0 ]]
    grep -q "sacred config" "$FAKE_HOME/.config/picom.conf"
    ! ls "$FAKE_HOME/.config/picom.conf.bak."* 2>/dev/null
}

@test "picom: second run succeeds" {
    run_script
    run run_script
    [[ "$status" -eq 0 ]]
}
