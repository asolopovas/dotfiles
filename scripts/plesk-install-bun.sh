#!/bin/bash
set -euo pipefail

# Install/update bun globally for all Plesk vhost users with a shared cache.
# Only root should run this script.
#
# Architecture:
#   /usr/local/bin/bun        - Wrapper script (entry point for all users)
#   /usr/local/bin/bun-bin    - Actual bun binary (root-owned, 755)
#   /usr/local/bin/bun-run    - Helper that runs bun as root for cache writes,
#                               then chowns node_modules back to calling user
#   /usr/local/bin/bunx       - Symlink to bun wrapper
#   /var/www/bun-cache        - Shared cache (root-owned, 755 — users can read
#                               for hardlinks but cannot write or delete)
#   /etc/profile.d/bun.sh    - Sets BUN_INSTALL_CACHE_DIR for login shells
#   /etc/sudoers.d/bun-cache - Allows all users to sudo bun-run
#
# Security:
#   - Cache is root:root 755 — users cannot modify or delete cached packages
#   - bun-run is the only elevated path, restricted via sudoers
#   - node_modules ownership is restored to the calling user after install
#   - Only root can update the bun binary (re-run this script)
#
# To update bun, just re-run this script as root.

CACHE_DIR="/var/www/bun-cache"
BUN_BIN="/usr/local/bin/bun-bin"
BUN_RUN="/usr/local/bin/bun-run"
BUN_WRAPPER="/usr/local/bin/bun"
BUNX_LINK="/usr/local/bin/bunx"
PROFILE_SCRIPT="/etc/profile.d/bun.sh"
SUDOERS_FILE="/etc/sudoers.d/bun-cache"

source "$(dirname "$0")/../globals.sh"

if [[ $EUID -ne 0 ]]; then
    print_color red "This script must be run as root"
    exit 1
fi

# --- Download latest bun ---
print_color green "Downloading latest bun..."
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

curl -fsSL https://bun.sh/install | BUN_INSTALL="$TMP_DIR" bash

if [[ ! -f "$TMP_DIR/bin/bun" ]]; then
    print_color red "Failed to download bun"
    exit 1
fi

NEW_VERSION=$("$TMP_DIR/bin/bun" --version)
print_color green "Downloaded bun v${NEW_VERSION}"

# --- Install binary ---
if [[ -f "$BUN_BIN" ]]; then
    OLD_VERSION=$("$BUN_BIN" --version 2>/dev/null || echo "unknown")
    print_color yellow "Replacing bun v${OLD_VERSION} with v${NEW_VERSION}"
fi

cp "$TMP_DIR/bin/bun" "$BUN_BIN"
chmod 755 "$BUN_BIN"
chown root:root "$BUN_BIN"

# --- Create bun-run helper (runs as root via sudo) ---
print_color green "Installing bun-run helper at ${BUN_RUN}..."
cat > "$BUN_RUN" << 'HELPER'
#!/bin/bash
# Runs bun-bin as root (for cache writes), then chowns outputs back to caller.
# Called by the bun wrapper via sudo. Do NOT call directly.
CALLER_USER="$1"
CALLER_GROUP="$2"
WORK_DIR="$3"
shift 3

export BUN_INSTALL_CACHE_DIR="/var/www/bun-cache"
cd "$WORK_DIR" || exit 1

/usr/local/bin/bun-bin "$@"
status=$?

# Fix node_modules ownership back to calling user
if [[ -d "node_modules" ]]; then
    chown -R "${CALLER_USER}:${CALLER_GROUP}" node_modules 2>/dev/null &
fi
# Fix lockfiles if bun created or updated them
for f in bun.lock bun.lockb; do
    if [[ -f "$f" ]]; then
        chown "${CALLER_USER}:${CALLER_GROUP}" "$f" 2>/dev/null
    fi
done

exit $status
HELPER
chmod 755 "$BUN_RUN"
chown root:root "$BUN_RUN"

# --- Create wrapper ---
print_color green "Installing bun wrapper at ${BUN_WRAPPER}..."
cat > "$BUN_WRAPPER" << 'WRAPPER'
#!/bin/bash
# Bun wrapper: elevates to root via sudo for shared cache writes.
# Cache is root-owned — users can read (hardlinks) but not write directly.
export BUN_INSTALL_CACHE_DIR="/var/www/bun-cache"

CALLER_USER=$(id -un)
CALLER_GROUP=$(id -gn)
WORK_DIR=$(pwd)

if [[ "$CALLER_USER" == "root" ]]; then
    /usr/local/bin/bun-bin "$@"
else
    sudo /usr/local/bin/bun-run "$CALLER_USER" "$CALLER_GROUP" "$WORK_DIR" "$@"
fi
WRAPPER
chmod 755 "$BUN_WRAPPER"
chown root:root "$BUN_WRAPPER"

# --- Create bunx symlink ---
ln -sf "$BUN_WRAPPER" "$BUNX_LINK"

# --- Create shared cache directory ---
if [[ ! -d "$CACHE_DIR" ]]; then
    print_color green "Creating shared cache at ${CACHE_DIR}..."
    mkdir -p "$CACHE_DIR"
fi
chown root:root "$CACHE_DIR"
chmod 755 "$CACHE_DIR"

# --- Lock down existing cache contents ---
if [[ -d "$CACHE_DIR" ]] && [[ "$(ls -A "$CACHE_DIR" 2>/dev/null)" ]]; then
    print_color green "Locking cache permissions (root-owned, world-readable)..."
    chown -R root:root "$CACHE_DIR"
    chmod -R u+rwX,go+rX,go-w "$CACHE_DIR"
fi

# --- Configure sudoers ---
print_color green "Configuring sudoers..."
cat > "$SUDOERS_FILE" << 'SUDOERS'
ALL ALL=(root) NOPASSWD: /usr/local/bin/bun-run *
SUDOERS
chmod 440 "$SUDOERS_FILE"
if ! visudo -cf "$SUDOERS_FILE" >/dev/null 2>&1; then
    print_color red "Sudoers syntax check failed, removing ${SUDOERS_FILE}"
    rm -f "$SUDOERS_FILE"
    exit 1
fi

# --- Set global environment variable ---
print_color green "Setting BUN_INSTALL_CACHE_DIR in ${PROFILE_SCRIPT}..."
cat > "$PROFILE_SCRIPT" << EOF
export BUN_INSTALL_CACHE_DIR="${CACHE_DIR}"
EOF
chmod 644 "$PROFILE_SCRIPT"

# --- Remove per-user bun installations ---
print_color yellow "Checking for per-user bun installations..."
removed=0
for bun_dir in /var/www/vhosts/*/.bun; do
    if [[ -d "$bun_dir" ]]; then
        site=$(basename "$(dirname "$bun_dir")")
        print_color yellow "  Removing ${bun_dir} (${site})"
        rm -rf "$bun_dir"
        ((removed++))
    fi
done

if [[ $removed -gt 0 ]]; then
    print_color green "Removed ${removed} per-user bun installation(s)"
else
    print_color green "No per-user bun installations found"
fi

# --- Verify ---
print_color green "Verifying installation..."
INSTALLED_VERSION=$("$BUN_WRAPPER" --version)
print_color bold_green "bun v${INSTALLED_VERSION} installed globally at ${BUN_WRAPPER}"
print_color bold_green "Shared cache at ${CACHE_DIR} (root-owned, users cannot modify)"
print_color green "All Plesk vhost users can use bun via the wrapper"
