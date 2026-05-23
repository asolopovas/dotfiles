#!/bin/bash
set -euo pipefail

URL="${WSL_HELLO_URL:-https://github.com/evanphilip/WSL-Hello-sudo/releases/latest/download/release.tar.gz}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

need() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Missing required command: $1" >&2
        exit 1
    }
}

wsl_root() {
    if [[ -r /etc/wsl.conf ]]; then
        awk -F= '/^[[:space:]]*root[[:space:]]*=/{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit}' /etc/wsl.conf
    fi
}

pam_dir() {
    local dir
    for dir in "/lib/$(uname -m)-linux-gnu/security" /lib/security /usr/lib/security; do
        if [[ -d "$dir" ]] && compgen -G "$dir/pam_*.so" >/dev/null; then
            printf '%s\n' "$dir"
            return
        fi
    done
    echo "PAM module directory not found" >&2
    exit 1
}

pam_sudo_fallback() {
    grep -q 'pam_wsl_hello\.so' /etc/pam.d/sudo && return
    local file="$TMP/sudo.pam"
    printf 'auth sufficient pam_wsl_hello.so\n' >"$file"
    cat /etc/pam.d/sudo >>"$file"
    sudo install -m 644 "$file" /etc/pam.d/sudo
}

windows_program_dir() {
    if command -v powershell.exe >/dev/null 2>&1 && command -v wslpath >/dev/null 2>&1; then
        local appdata path
        appdata="$(powershell.exe -NoProfile -Command '[Environment]::GetFolderPath("LocalApplicationData")' 2>/dev/null | tr -d '\r' | tail -n 1)"
        if [[ -n "$appdata" ]] && path="$(wslpath -u "$appdata")"; then
            printf '%s/Programs/wsl-hello-sudo\n' "$path"
            return
        fi
    fi
    printf '%s/Users/%s/AppData/Local/Programs/wsl-hello-sudo\n' "$MNT" "$WIN_USER"
}

[[ "${EUID:-$(id -u)}" -ne 0 ]] || {
    echo "Run as your WSL user, not root" >&2
    exit 1
}

grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null || {
    echo "This installer must run inside WSL" >&2
    exit 1
}

need curl
need tar
need sudo

ROOT="$(wsl_root)"
ROOT="${ROOT:-/mnt}"
ROOT="${ROOT%/}"
[[ "$ROOT" == "/" ]] && MNT="/c" || MNT="$ROOT/c"
[[ -x "$MNT/Windows/System32/whoami.exe" ]] || {
    echo "Windows interop is not available at $MNT" >&2
    exit 1
}

LINUX_USER="$(id -un)"
WIN_USER="$({ "$MNT/Windows/System32/whoami.exe" || true; } | tr -d '\r' | awk -F'\\' 'NF > 1 {print $2; exit}')"
[[ -n "$WIN_USER" ]] || {
    echo "Could not detect Windows user" >&2
    exit 1
}

WIN_PATH="${PAM_WSL_HELLO_WINPATH:-$(windows_program_dir)}"
SECURITY_PATH="$(pam_dir)"

curl -fsSL "$URL" -o "$TMP/release.tar.gz"
tar xzf "$TMP/release.tar.gz" -C "$TMP"
RELEASE="$TMP/release"
[[ -d "$RELEASE" ]] || RELEASE="$TMP"
[[ -f "$RELEASE/build/pam_wsl_hello.so" && -f "$RELEASE/build/WindowsHelloBridge.exe" && -f "$RELEASE/pam-config" ]] || {
    echo "Release archive is missing WSL Hello files" >&2
    exit 1
}

mkdir -p "$WIN_PATH"
cp "$RELEASE/build/WindowsHelloBridge.exe" "$WIN_PATH/"
chmod +x "$WIN_PATH/WindowsHelloBridge.exe"

OLD_KEY="$MNT/Users/$WIN_USER/pam_wsl_hello/pam_wsl_hello_$LINUX_USER.pem"
KEY="$WIN_PATH/pam_wsl_hello_$LINUX_USER.pem"
if [[ -f "$OLD_KEY" && ! -f "$KEY" ]]; then
    mv "$OLD_KEY" "$KEY"
    rmdir "$MNT/Users/$WIN_USER/pam_wsl_hello" 2>/dev/null || true
fi

sudo install -m 644 -o root -g root "$RELEASE/build/pam_wsl_hello.so" "$SECURITY_PATH/pam_wsl_hello.so"
if [[ -d /usr/share/pam-configs ]]; then
    sudo install -m 644 -o root -g root "$RELEASE/pam-config" /usr/share/pam-configs/wsl-hello
fi

sudo mkdir -p /etc/pam_wsl_hello/public_keys
{
    printf 'authenticator_path = "%s/WindowsHelloBridge.exe"\n' "$WIN_PATH"
    printf 'win_mnt = "%s"\n' "$MNT"
} | sudo tee /etc/pam_wsl_hello/config >/dev/null

set +e
(
    cd "$WIN_PATH" && ./WindowsHelloBridge.exe creator "pam_wsl_hello_$LINUX_USER"
)
CREATE_STATUS=$?
set -e
[[ "$CREATE_STATUS" -eq 0 || "$CREATE_STATUS" -eq 171 ]] || exit "$CREATE_STATUS"
[[ -f "$KEY" ]] || {
    echo "Windows Hello key was not created: $KEY" >&2
    exit 1
}
sudo install -m 644 -o root -g root "$KEY" /etc/pam_wsl_hello/public_keys/

if command -v pam-auth-update >/dev/null 2>&1 && [[ -d /usr/share/pam-configs ]]; then
    sudo env DEBIAN_FRONTEND=noninteractive pam-auth-update --enable wsl-hello
else
    pam_sudo_fallback
fi

sudo -k
echo "Confirm sudo with Windows Hello or PIN"
sudo -v
echo "WSL sudo Windows Hello authentication is installed"
