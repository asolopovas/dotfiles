#!/usr/bin/env bats

# Static lint suite for scripts/inst-*.sh.
# Verifies each install script follows the project's standard pattern:
#   - bash shebang
#   - `set -e` (or set -euo pipefail)
#   - syntactically valid (bash -n)
#   - sources globals.sh OR is documented as exempt
#
# Does NOT execute installs (would touch the system / require sudo / network).

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPTS_DIR="$REPO_DIR/scripts"

# Scripts intentionally exempt from the standard pattern (config dumps,
# heavy interactive setup, or third-party-shaped installers).
EXEMPT=(
    inst-cinnamon-settings.sh
    inst-grub.sh
    inst-menu.sh
    inst-nvim.sh
    inst-picom.sh
    inst-redis-service.sh
    inst-samba.sh
    inst-software.sh
    inst-xmonad.sh
)

is_exempt() {
    local name="$1"
    for e in "${EXEMPT[@]}"; do
        [[ "$name" == "$e" ]] && return 0
    done
    return 1
}

each_script() {
    find "$SCRIPTS_DIR" -maxdepth 1 -name 'inst-*.sh' -type f | sort
}

@test "every inst-*.sh has a bash/sh shebang" {
    local fail=0
    while IFS= read -r f; do
        local first
        first="$(head -n1 "$f")"
        if [[ "$first" != "#!/bin/bash" \
            && "$first" != "#!/usr/bin/env bash" \
            && "$first" != "#!/bin/sh" ]]; then
            echo "missing/invalid shebang: $f -> $first"
            fail=1
        fi
    done < <(each_script)
    [ "$fail" -eq 0 ]
}

@test "every inst-*.sh passes bash -n syntax check" {
    local fail=0
    while IFS= read -r f; do
        if ! bash -n "$f" 2>/dev/null; then
            echo "syntax error in $f:"
            bash -n "$f" || true
            fail=1
        fi
    done < <(each_script)
    [ "$fail" -eq 0 ]
}

@test "non-exempt scripts use set -e (or stricter)" {
    local fail=0
    while IFS= read -r f; do
        local name; name="$(basename "$f")"
        is_exempt "$name" && continue
        if ! grep -qE '^set -[eu]+|^set -e' "$f"; then
            echo "missing 'set -e' in $f"
            fail=1
        fi
    done < <(each_script)
    [ "$fail" -eq 0 ]
}

@test "non-exempt scripts source globals.sh" {
    local fail=0
    while IFS= read -r f; do
        local name; name="$(basename "$f")"
        is_exempt "$name" && continue
        if ! grep -q 'globals\.sh' "$f"; then
            echo "missing 'source globals.sh' in $f"
            fail=1
        fi
    done < <(each_script)
    [ "$fail" -eq 0 ]
}

@test "no hardcoded version pins in inst-*.sh (besides exempt set)" {
    # Heuristic: VER="x.y.z" or VERSION="x.y.z" lines that look pinned.
    # Exempts:
    #   - inst-php.sh (major.minor selector by design)
    #   - inst-rye.sh (Python toolchain pin by design)
    local pin_exempt=(inst-php.sh inst-rye.sh "${EXEMPT[@]}")
    local is_pe=0 fail=0
    while IFS= read -r f; do
        local name; name="$(basename "$f")"
        is_pe=0
        for e in "${pin_exempt[@]}"; do [[ "$name" == "$e" ]] && is_pe=1; done
        [ "$is_pe" -eq 1 ] && continue
        if grep -qE '^(VER|VERSION)="[0-9]+\.[0-9]+(\.[0-9]+)?[a-z]?"' "$f"; then
            echo "hardcoded version pin in $f:"
            grep -nE '^(VER|VERSION)="[0-9]+\.[0-9]+(\.[0-9]+)?[a-z]?"' "$f"
            fail=1
        fi
    done < <(each_script)
    [ "$fail" -eq 0 ]
}

@test "globals.sh: gh_latest_release helper is defined" {
    grep -q '^gh_latest_release()' "$REPO_DIR/globals.sh"
}

@test "globals.sh: print_color/cmd_exist helpers are defined" {
    grep -q '^print_color()' "$REPO_DIR/globals.sh"
    grep -q '^cmd_exist()' "$REPO_DIR/globals.sh"
}
