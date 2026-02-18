#!/bin/bash
set -euo pipefail

# Install/update nvim globally for all Plesk vhost users with shared read-only data.
# Only root should run this script. Re-run to update plugins/LSPs/parsers.
#
# Architecture:
#   /opt/nvim/bin/nvim        - Actual nvim binary (root-owned)
#   /usr/local/bin/nvim       - Wrapper: sets XDG_DATA_HOME for non-root users only
#   /usr/local/bin/vim        - Symlink to wrapper
#   /opt/nvim-data/nvim/      - Shared data (root:root 755 — users can read, not write)
#     lazy/                   - lazy.nvim + all plugins
#     mason/                  - Mason LSP servers (lua-language-server, intelephense, json-lsp)
#   /etc/profile.d/nvim.sh   - Adds /opt/nvim/bin to PATH for all users
#
# Note: XDG_DATA_HOME=/opt/nvim-data makes stdpath("data") = /opt/nvim-data/nvim
#
# Security:
#   - Shared data is root:root 755 — users cannot modify plugins or LSP servers
#   - XDG_DATA_HOME override is scoped to the nvim process via wrapper (no global side effects)
#   - Only root can update plugins (re-run this script)

SHARED_XDG="/opt/nvim-data"
SHARED_DATA="/opt/nvim-data/nvim"
SHARED_CONFIG="/opt/nvim-config"
NVIM_BIN="/opt/nvim/bin/nvim"
NVIM_WRAPPER="/usr/local/bin/nvim"
VIM_LINK="/usr/local/bin/vim"
PROFILE_SCRIPT="/etc/profile.d/nvim.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/../globals.sh"

if [[ $EUID -ne 0 ]]; then
    print_color red "This script must be run as root"
    exit 1
fi

# --- Ensure nvim binary ---
if [[ ! -x "$NVIM_BIN" ]]; then
    print_color green "Installing nvim binary to /opt/nvim/..."
    INSTALL_ARCHIVE="nvim-linux-x86_64.tar.gz"
    URL="https://github.com/neovim/neovim/releases/latest/download/$INSTALL_ARCHIVE"
    TMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TMP_DIR"' EXIT
    curl -fsSL -o "$TMP_DIR/$INSTALL_ARCHIVE" "$URL"
    rm -rf /opt/nvim
    tar -xzf "$TMP_DIR/$INSTALL_ARCHIVE" -C /opt
    mv /opt/nvim-linux-x86_64 /opt/nvim
fi
print_color green "nvim binary: $($NVIM_BIN --version | head -1)"

# --- Create wrapper (scopes XDG_DATA_HOME to nvim process only) ---
print_color green "Installing nvim wrapper at ${NVIM_WRAPPER}..."
cat > "$NVIM_WRAPPER" << 'WRAPPER'
#!/bin/bash
if [ "$(id -u)" -ne 0 ] && [ -d /opt/nvim-data/nvim/lazy ]; then
    exec env \
        XDG_CONFIG_HOME=/opt/nvim-config \
        XDG_DATA_HOME=/opt/nvim-data \
        XDG_STATE_HOME="$HOME/.local/state" \
        XDG_CACHE_HOME="$HOME/.cache" \
        /opt/nvim/bin/nvim "$@"
fi
exec /opt/nvim/bin/nvim "$@"
WRAPPER
chmod 755 "$NVIM_WRAPPER"
chown root:root "$NVIM_WRAPPER"
ln -sf "$NVIM_WRAPPER" "$VIM_LINK"

# Override any direct symlinks to the binary (e.g. from inst-nvim.sh install_root)
# so all users go through the wrapper
for link in /usr/bin/nvim /usr/bin/vim; do
    if [ -L "$link" ] && [ "$(readlink -f "$link")" = "$NVIM_BIN" ]; then
        ln -sf "$NVIM_WRAPPER" "$link"
    fi
done

# --- Ensure root has nvim config symlink ---
NVIM_CONFIG="$HOME/.config/nvim"
SOURCE_CONFIG="$HOME/dotfiles/.config/nvim"
if [ -d "$SOURCE_CONFIG" ] && [ ! -e "$NVIM_CONFIG" ]; then
    mkdir -p "$HOME/.config"
    ln -sf "$SOURCE_CONFIG" "$NVIM_CONFIG"
fi

# --- Copy config to shared read-only location for vhost users ---
# XDG_CONFIG_HOME=/opt/nvim-config makes stdpath("config") = /opt/nvim-config/nvim
print_color green "Copying nvim config to ${SHARED_CONFIG}/nvim/..."
mkdir -p "$SHARED_CONFIG/nvim"
rsync -a --delete "$SOURCE_CONFIG/" "$SHARED_CONFIG/nvim/"
chown -R root:root "$SHARED_CONFIG"
chmod -R u+rwX,go+rX,go-w "$SHARED_CONFIG"

# --- Helper: run nvim headless with timeout and forced exit ---
nvim_headless() {
    local desc="$1"
    local lua_code="$2"
    local wait="${3:-120}"

    print_color green "$desc"
    timeout "$wait" env XDG_DATA_HOME="$SHARED_XDG" "$NVIM_BIN" --headless \
        -c "lua $lua_code" 2>&1 || {
        local rc=$?
        if [[ $rc -eq 124 ]]; then
            print_color yellow "  Timed out after ${wait}s (may still be OK)"
        else
            print_color yellow "  Exited with code $rc"
        fi
    }
}

# --- Sync shared data ---
mkdir -p "$SHARED_DATA"

nvim_headless "Syncing plugins..." \
    "local ok,lazy=pcall(require,'lazy'); if ok then lazy.sync({wait=true}) end; vim.cmd('qa!')" \
    120

nvim_headless "Installing Mason LSP servers..." \
    "
    local reg = require('mason-registry')
    reg.refresh(function()
        local pkgs = {'lua-language-server','intelephense','json-lsp'}
        local done, total = 0, #pkgs
        for _,name in ipairs(pkgs) do
            local ok, pkg = pcall(reg.get_package, name)
            if ok and not pkg:is_installed() then
                pkg:install():on('closed', function()
                    done = done + 1
                    if done >= total then vim.schedule(function() vim.cmd('qa!') end) end
                end)
            else
                done = done + 1
                if done >= total then vim.schedule(function() vim.cmd('qa!') end) end
            end
        end
    end)
    " 120

print_color green "Installing Treesitter parsers..."
timeout 120 env XDG_DATA_HOME="$SHARED_XDG" "$NVIM_BIN" --headless \
    -c "lua local langs={'vimdoc','javascript','typescript','lua','jsdoc','bash','php','fish'}; for _,l in ipairs(langs) do vim.cmd('TSInstallSync! '..l) end; vim.cmd('qa!')" 2>&1 || {
    rc=$?
    if [[ $rc -eq 124 ]]; then
        print_color yellow "  Timed out after 120s (may still be OK)"
    else
        print_color yellow "  Exited with code $rc"
    fi
}

# --- Lock permissions ---
print_color green "Setting permissions (root-owned, world-readable)..."
chown -R root:root "$SHARED_XDG"
chmod -R u+rwX,go+rX,go-w "$SHARED_XDG"
find "$SHARED_DATA/mason" -type f \( -name "*.sh" -o -path "*/bin/*" \) -exec chmod 755 {} + 2>/dev/null || true

# --- PATH for all users ---
# Wrapper at /usr/local/bin/nvim handles XDG_DATA_HOME for non-root.
# Do NOT add /opt/nvim/bin to PATH — users must hit the wrapper, not the raw binary.
# /usr/local/bin is already in default PATH on Debian/Ubuntu.
# Remove stale profile script if it previously added /opt/nvim/bin.
rm -f "$PROFILE_SCRIPT"

# --- Clean per-user nvim installs and config symlinks ---
print_color yellow "Cleaning per-user nvim installations..."
removed=0
for vhost_home in /var/www/vhosts/*/; do
    [[ -d "${vhost_home}" ]] || continue
    # Remove per-user data/cache/binary dirs
    for d in .local/nvim .local/share/nvim .cache/nvim; do
        if [[ -d "${vhost_home}${d}" ]]; then
            print_color yellow "  Removing ${vhost_home}${d}"
            rm -rf "${vhost_home}${d}"
            ((removed++))
        fi
    done
    # Remove per-user nvim config symlink (users will use root's config via
    # their dotfiles clone after plesk-update-dotfiles.sh syncs the repo)
    nvim_link="${vhost_home}.config/nvim"
    if [[ -L "$nvim_link" ]]; then
        print_color yellow "  Removing config symlink ${nvim_link}"
        rm -f "$nvim_link"
        ((removed++))
    fi
done
[[ $removed -gt 0 ]] && print_color green "Removed ${removed} per-user nvim item(s)" \
                      || print_color green "No per-user nvim items found"

# --- Verify ---
echo ""
print_color bold_green "Setup complete:"
print_color green "  Binary:  $NVIM_BIN"
print_color green "  Wrapper: $NVIM_WRAPPER (XDG_DATA_HOME for non-root only)"
print_color green "  Data:    $SHARED_DATA (root-owned, read-only for users)"
echo ""
print_color green "Shared data contents:"
du -sh "$SHARED_DATA"/lazy "$SHARED_DATA"/mason 2>/dev/null || true
echo ""
print_color green "Mason packages:"
ls "$SHARED_DATA/mason/packages/" 2>/dev/null || echo "  (none)"
echo ""
print_color green "Treesitter parsers:"
ls "$SHARED_DATA/treesitter/" 2>/dev/null || ls "$SHARED_DATA"/lazy/nvim-treesitter/parser/*.so 2>/dev/null | xargs -I{} basename {} .so || echo "  (none)"
