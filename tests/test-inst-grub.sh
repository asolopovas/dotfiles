#!/bin/bash

set -u

PASS=0
FAIL=0

check() {
    local desc="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        printf '  \033[32mPASS\033[0m  %s\n' "$desc"
        PASS=$((PASS + 1))
    else
        printf '  \033[31mFAIL\033[0m  %s\n' "$desc"
        FAIL=$((FAIL + 1))
    fi
}

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo $0"
    exit 1
fi

echo "== /etc/default/grub =="
check "GRUB_DEFAULT=saved" grep -q '^GRUB_DEFAULT=saved' /etc/default/grub
check "GRUB_SAVEDEFAULT=true" grep -q '^GRUB_SAVEDEFAULT=true' /etc/default/grub
check "GRUB_TIMEOUT_STYLE=menu" grep -q '^GRUB_TIMEOUT_STYLE=menu' /etc/default/grub
check "GRUB_TIMEOUT=5" grep -q '^GRUB_TIMEOUT=5' /etc/default/grub
check "GRUB_DISABLE_SUBMENU=y" grep -q '^GRUB_DISABLE_SUBMENU=y' /etc/default/grub

echo "== /etc/default/grub.d =="
check "60_linuxmint_name.cfg sets GRUB_DISTRIBUTOR=\"Linux Mint\"" \
    grep -q 'GRUB_DISTRIBUTOR="Linux Mint"' /etc/default/grub.d/60_linuxmint_name.cfg

echo "== /etc/grub.d scripts =="
check "10_linux recognizes 'Linux Mint'" grep -q '"Linux Mint"' /etc/grub.d/10_linux
check "05_debian_theme recognizes 'Linux Mint'" grep -q '"Linux Mint"' /etc/grub.d/05_debian_theme

WIN_DEV=$(os-prober 2>/dev/null | awk -F'[@:]' '/Windows/ {print $1; exit}')
if [ -n "$WIN_DEV" ]; then
    WIN_UUID=$(blkid -s UUID -o value "$WIN_DEV")
    echo "== Windows entry (detected $WIN_DEV, UUID=$WIN_UUID) =="
    check "06_windows exists" test -f /etc/grub.d/06_windows
    check "06_windows is executable" test -x /etc/grub.d/06_windows
    check "06_windows contains 'Windows 11' menuentry" \
        grep -q 'menuentry "Windows 11"' /etc/grub.d/06_windows
    check "06_windows references correct UUID" \
        grep -q "$WIN_UUID" /etc/grub.d/06_windows
    check "06_windows menuentry contains 'savedefault' (remembers last boot)" \
        grep -q '^\s*savedefault' /etc/grub.d/06_windows
    check "40_custom does NOT contain Windows entry" \
        bash -c '! grep -q "menuentry \"Windows 11\"" /etc/grub.d/40_custom'
    check "os-prober skip list set for this UUID" \
        grep -q "GRUB_OS_PROBER_SKIP_LIST=\"${WIN_UUID}@" /etc/default/grub.d/50_linuxmint.cfg

    echo "== /boot/grub/grub.cfg menu order =="
    WIN_LINE=$(grep -n '^menuentry "Windows 11"' /boot/grub/grub.cfg | head -1 | cut -d: -f1)
    LIN_LINE=$(grep -n "^menuentry 'Linux Mint" /boot/grub/grub.cfg | head -1 | cut -d: -f1)
    if [ -n "$WIN_LINE" ] && [ -n "$LIN_LINE" ] && [ "$WIN_LINE" -lt "$LIN_LINE" ]; then
        printf '  \033[32mPASS\033[0m  Windows 11 appears before Linux Mint (line %s < %s)\n' "$WIN_LINE" "$LIN_LINE"
        PASS=$((PASS + 1))
    else
        printf '  \033[31mFAIL\033[0m  Windows 11 should appear before Linux Mint (win=%s lin=%s)\n' "$WIN_LINE" "$LIN_LINE"
        FAIL=$((FAIL + 1))
    fi
else
    echo "== Windows entry =="
    echo "  SKIP  os-prober did not detect Windows"
fi

echo
echo "Result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
