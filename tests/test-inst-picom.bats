#!/usr/bin/env bats

# ---------------------------------------------------------------------------
# Unit tests for inst-picom.sh — picom source build + perf-tuned config.
# Mocks apt, git, meson, ninja, pkill, pgrep, nvidia-smi. No network, no sudo.
# ---------------------------------------------------------------------------

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="$REPO_DIR/scripts/inst/inst-picom.sh"

setup() {
    export FAKE_HOME="$(mktemp -d)"
    export TMPDIR="$(mktemp -d)"
    export FAKE_BIN="$TMPDIR/fake-bin"
    mkdir -p "$FAKE_BIN" "$FAKE_HOME/.config" "$FAKE_HOME/.local/bin"

    # sudo: pass-through (skip flags, run inner command)
    cat > "$FAKE_BIN/sudo" <<'S'
#!/bin/sh
while [ $# -gt 0 ]; do case "$1" in -n|-E) shift;; -*) shift;; *) break;; esac; done
"$@"
S

    # apt-get / meson / pkill / nvidia-smi: succeed silently
    for bin in apt-get meson pkill nvidia-smi; do
        printf '#!/bin/sh\nexit 0\n' > "$FAKE_BIN/$bin"
    done

    # git clone: create the target dir (last positional arg)
    cat > "$FAKE_BIN/git" <<'G'
#!/bin/sh
if [ "$1" = clone ]; then
    for a; do target="$a"; done
    mkdir -p "$target"
fi
exit 0
G

    # pgrep: simulate "picom is running" so the post-start check passes
    printf '#!/bin/sh\necho 12345\nexit 0\n' > "$FAKE_BIN/pgrep"

    # ninja: on `install` invocation, plant a fake picom at $HOME/.local/bin
    cat > "$FAKE_BIN/ninja" <<N
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
    env HOME="$FAKE_HOME" PATH="$FAKE_BIN:$PATH" TMPDIR="$TMPDIR" \
        bash "$SCRIPT" "$@"
}

# =====================================================================
#  Build / install flow
# =====================================================================

@test "picom: script exists and is executable" {
    [ -x "$SCRIPT" ]
}

@test "picom: syntax is valid bash" {
    run bash -n "$SCRIPT"
    [[ "$status" -eq 0 ]]
}

@test "picom: fresh run installs binary to ~/.local/bin" {
    run run_script
    [[ "$status" -eq 0 ]]
    [ -x "$FAKE_HOME/.local/bin/picom" ]
}

@test "picom: skips rebuild when requested tag already installed" {
    # Pre-plant a "v13" binary and config so only restart path runs
    cat > "$FAKE_HOME/.local/bin/picom" <<'P'
#!/bin/sh
case "$1" in --version) echo "v13";; *) exit 0;; esac
P
    chmod +x "$FAKE_HOME/.local/bin/picom"

    run run_script
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"already installed"* ]]
    [[ "$output" != *"Cloning picom"* ]]
}

@test "picom: FORCE=true rebuilds even when already installed" {
    cat > "$FAKE_HOME/.local/bin/picom" <<'P'
#!/bin/sh
case "$1" in --version) echo "v13";; *) exit 0;; esac
P
    chmod +x "$FAKE_HOME/.local/bin/picom"

    run env FORCE=true HOME="$FAKE_HOME" PATH="$FAKE_BIN:$PATH" TMPDIR="$TMPDIR" bash "$SCRIPT"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Cloning picom"* ]]
}

@test "picom: PICOM_TAG overrides default tag" {
    run env PICOM_TAG=v12 HOME="$FAKE_HOME" PATH="$FAKE_BIN:$PATH" TMPDIR="$TMPDIR" bash "$SCRIPT"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"v12"* ]]
}

# =====================================================================
#  Config generation
# =====================================================================

@test "picom: writes ~/.config/picom.conf" {
    run run_script
    [[ "$status" -eq 0 ]]
    [ -f "$FAKE_HOME/.config/picom.conf" ]
}

@test "picom: config enables unredir-if-possible" {
    run_script
    grep -q '^unredir-if-possible = true' "$FAKE_HOME/.config/picom.conf"
}

# bats does not implicitly `set -e`; chain assertions with && so each one gates.

@test "picom: config disables shadow, fading, corner-radius" {
    run_script
    grep -q '^shadow = false'    "$FAKE_HOME/.config/picom.conf" && \
    grep -q '^fading = false'    "$FAKE_HOME/.config/picom.conf" && \
    grep -q '^corner-radius = 0' "$FAKE_HOME/.config/picom.conf"
}

@test "picom: config has no blur-method or blur-kern lines" {
    run_script
    ! grep -Eq '^(blur-method|blur-kern)' "$FAKE_HOME/.config/picom.conf"
}

@test "picom: config enables NVIDIA GLX tuning flags" {
    run_script
    grep -q '^backend = "glx"'           "$FAKE_HOME/.config/picom.conf" && \
    grep -q '^vsync = true'              "$FAKE_HOME/.config/picom.conf" && \
    grep -q '^xrender-sync-fence = true' "$FAKE_HOME/.config/picom.conf" && \
    grep -q '^use-damage = true'         "$FAKE_HOME/.config/picom.conf"
}

@test "picom: config omits deprecated GLX options (v11+)" {
    run_script
    ! grep -Eq '^glx-no-(stencil|rebind-pixmap)' "$FAKE_HOME/.config/picom.conf"
}

@test "picom: config sets all opacity to 1.0" {
    run_script
    grep -q '^inactive-opacity = 1.0' "$FAKE_HOME/.config/picom.conf" && \
    grep -q '^active-opacity = 1.0'   "$FAKE_HOME/.config/picom.conf" && \
    grep -q '^frame-opacity = 1.0'    "$FAKE_HOME/.config/picom.conf"
}

# =====================================================================
#  Backup behavior
# =====================================================================

@test "picom: backs up existing config with timestamped suffix" {
    echo "# old config" > "$FAKE_HOME/.config/picom.conf"
    run_script
    local backups=("$FAKE_HOME/.config/picom.conf.bak."*)
    [ -f "${backups[0]}" ]
    grep -q "old config" "${backups[0]}"
}

@test "picom: no backup created on fresh install" {
    run_script
    local backups=("$FAKE_HOME/.config/picom.conf.bak."*)
    # Glob stays literal when no match — so file won't exist
    [ ! -e "${backups[0]}" ]
}

@test "picom: KEEP_CONFIG=true leaves existing config untouched" {
    echo "# sacred config" > "$FAKE_HOME/.config/picom.conf"
    run env KEEP_CONFIG=true HOME="$FAKE_HOME" PATH="$FAKE_BIN:$PATH" TMPDIR="$TMPDIR" bash "$SCRIPT"
    [[ "$status" -eq 0 ]]
    grep -q "sacred config" "$FAKE_HOME/.config/picom.conf"
    ! ls "$FAKE_HOME/.config/picom.conf.bak."* 2>/dev/null
}

# =====================================================================
#  Idempotency
# =====================================================================

@test "picom: second run succeeds (idempotent config write)" {
    run_script
    run run_script
    [[ "$status" -eq 0 ]]
}
