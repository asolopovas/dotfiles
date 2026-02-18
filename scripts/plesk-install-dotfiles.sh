#!/bin/bash
set -euo pipefail

# Share root's dotfiles, OMF, and opencode config with all Plesk vhost users.
# Only root should run this script. Re-run after dotfiles or config updates.
#
# Architecture:
#   /opt/dotfiles/              - Root-owned read-only copy of /root/dotfiles
#   /opt/omf/                   - Root-owned read-only Oh My Fish + bass plugin
#   /opt/opencode-config/       - Root-owned read-only opencode config (json, skills, plugins)
#   /usr/local/bin/opencode     - Shared opencode binary
#
# Per-vhost user:
#   ~/dotfiles                  - Symlink to /opt/dotfiles
#   ~/.config/fish, tmux, etc.  - Symlinks through ~/dotfiles
#   ~/.local/share/omf          - Symlink to /opt/omf
#   ~/.config/opencode          - Symlink to /opt/opencode-config
#   ~/.local/share/opencode/    - Per-user writable (db, auth, logs)
#   ~/.local/share/fish/        - Per-user writable (fish_history)
#   ~/.config/omf/              - Per-user writable omf config
#
# Root keeps its own ~/dotfiles and ~/.config/opencode, unaffected.

SHARED_DOTFILES="/opt/dotfiles"
SHARED_OMF="/opt/omf"
SHARED_OPENCODE="/opt/opencode-config"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/../globals.sh"

if [[ $EUID -ne 0 ]]; then
    print_color red "This script must be run as root"
    exit 1
fi

# --- Sync dotfiles to shared location ---
print_color green "Syncing dotfiles to ${SHARED_DOTFILES}..."
mkdir -p "$SHARED_DOTFILES"
rsync -a --delete \
    --exclude='.git' \
    --exclude='tests/' \
    /root/dotfiles/ "$SHARED_DOTFILES/"
chown -R root:root "$SHARED_DOTFILES"
chmod -R u+rwX,go+rX,go-w "$SHARED_DOTFILES"

# --- Install shared Oh My Fish + bass ---
if [[ ! -f "$SHARED_OMF/init.fish" ]] || [[ ! -d "$SHARED_OMF/pkg/bass" ]]; then
    print_color green "Installing shared Oh My Fish + bass to ${SHARED_OMF}..."
    rm -rf "$SHARED_OMF"
    TMP_INSTALL=$(mktemp)
    curl -sfo "$TMP_INSTALL" https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install
    # Install omf to shared path with a temp config dir
    TMP_OMF_CONF=$(mktemp -d)
    fish "$TMP_INSTALL" --noninteractive --path="$SHARED_OMF" --config="$TMP_OMF_CONF"
    fish -c "set -gx OMF_PATH $SHARED_OMF; set -gx OMF_CONFIG $TMP_OMF_CONF; source $SHARED_OMF/init.fish; omf install bass"
    rm -f "$TMP_INSTALL"
    rm -rf "$TMP_OMF_CONF"
fi
# Remove .git dirs from omf — not needed for read-only shared use
find "$SHARED_OMF" -name ".git" -type d -exec rm -rf {} + 2>/dev/null || true
chown -R root:root "$SHARED_OMF"
chmod -R u+rwX,go+rX,go-w "$SHARED_OMF"
print_color green "Shared OMF: $(du -sh "$SHARED_OMF" | cut -f1)"

# --- Shared opencode config ---
ROOT_OC="$HOME/.config/opencode"
if [[ -d "$ROOT_OC" ]]; then
    print_color green "Syncing opencode config to ${SHARED_OPENCODE}..."
    mkdir -p "$SHARED_OPENCODE"
    rsync -a --delete \
        --exclude='antigravity-accounts.json' \
        --exclude='antigravity-accounts.json.*.tmp' \
        --exclude='antigravity-signature-cache.json' \
        --exclude='antigravity-logs/' \
        --exclude='logs/' \
        "$ROOT_OC/" "$SHARED_OPENCODE/"
    chown -R root:root "$SHARED_OPENCODE"
    chmod -R u+rwX,go+rX,go-w "$SHARED_OPENCODE"
    print_color green "Shared opencode config: $(du -sh "$SHARED_OPENCODE" | cut -f1)"
fi

# --- Shared opencode binary ---
OC_BIN_SRC="$HOME/.bun/install/global/node_modules/opencode-linux-x64/bin/opencode"
OC_BIN_DEST="/usr/local/bin/opencode"
if [[ -x "$OC_BIN_SRC" ]] && [[ ! -x "$OC_BIN_DEST" || "$OC_BIN_SRC" -nt "$OC_BIN_DEST" ]]; then
    print_color green "Installing opencode binary to ${OC_BIN_DEST}..."
    cp "$OC_BIN_SRC" "$OC_BIN_DEST"
    chmod 755 "$OC_BIN_DEST"
    chown root:root "$OC_BIN_DEST"
fi

# --- Symlinks to create per vhost user ---
# These mirror cfg-default-dirs.sh but point through ~/dotfiles (which -> /opt/dotfiles)
SYMLINKS=(
    ".bashrc"
    ".gitconfig"
    ".Xresources"
    ".gitignore"
    ".config/.func"
    ".config/.aliasrc"
    ".config/btop/btop.conf"
    ".config/tmux"
)
# Fish config is handled separately — needs a real dir so fish_variables is writable

ensure_symlink() {
    local src="$1" dest="$2"
    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
        return
    fi
    [ -e "$dest" ] || [ -L "$dest" ] && rm -rf "$dest"
    mkdir -p "$(dirname "$dest")"
    ln -sf "$src" "$dest"
}

# --- Query Plesk vhost users ---
print_color green "Configuring vhost users..."
plesk_users="$(
    plesk db -N -B -e "
        SELECT d.name, s.login, s.home
        FROM domains d
        JOIN hosting h ON d.id = h.dom_id
        JOIN sys_users s ON h.sys_user_id = s.id
        WHERE d.htype = 'vrt_hst'
    " 2>/dev/null
)" || true

if [[ -z "$plesk_users" ]]; then
    print_color yellow "No Plesk users found"
    exit 0
fi

ok=0
skip=0
while IFS=$'\t' read -r domain plesk_user home_dir; do
    [[ -z "$domain" || -z "$plesk_user" || -z "$home_dir" ]] && continue

    if ! id "$plesk_user" &>/dev/null || [[ ! -d "$home_dir" ]]; then
        print_color yellow "  SKIP  $plesk_user -- user/home missing"
        skip=$((skip + 1))
        continue
    fi

    print_color green "  $plesk_user ($domain)"

    # Remove per-user dotfiles git clone, replace with symlink
    dotfiles_dir="$home_dir/dotfiles"
    if [ -d "$dotfiles_dir/.git" ]; then
        print_color yellow "    Removing per-user dotfiles clone"
        rm -rf "$dotfiles_dir"
    elif [ -d "$dotfiles_dir" ] && [ ! -L "$dotfiles_dir" ]; then
        print_color yellow "    Removing per-user dotfiles dir"
        rm -rf "$dotfiles_dir"
    fi
    ensure_symlink "$SHARED_DOTFILES" "$dotfiles_dir"

    # Remove per-user omf data, replace with symlink
    omf_data="$home_dir/.local/share/omf"
    if [ -d "$omf_data" ] && [ ! -L "$omf_data" ]; then
        print_color yellow "    Removing per-user omf data"
        rm -rf "$omf_data"
    fi
    mkdir -p "$home_dir/.local/share"
    ensure_symlink "$SHARED_OMF" "$omf_data"

    # Ensure omf config dir exists (per-user, writable)
    omf_conf="$home_dir/.config/omf"
    if [ ! -d "$omf_conf" ]; then
        mkdir -p "$omf_conf"
        echo "package bass" > "$omf_conf/bundle"
        echo "default" > "$omf_conf/theme"
        echo "default" > "$omf_conf/channel"
        chown -R "$plesk_user:" "$omf_conf"
    fi

    # Shared opencode config
    if [[ -d "$SHARED_OPENCODE" ]]; then
        oc_conf="$home_dir/.config/opencode"
        if [ -d "$oc_conf" ] && [ ! -L "$oc_conf" ]; then
            print_color yellow "    Removing per-user opencode config"
            rm -rf "$oc_conf"
        fi
        ensure_symlink "$SHARED_OPENCODE" "$oc_conf"
        chown -h "$plesk_user:" "$oc_conf" 2>/dev/null || true
    fi

    # Ensure .config and required parent dirs exist
    mkdir -p "$home_dir/.config" "$home_dir/.local/bin" "$home_dir/.local/share" "$home_dir/.cache"

    # Create config symlinks (same as cfg-default-dirs.sh)
    for src in "${SYMLINKS[@]}"; do
        src_path="$dotfiles_dir/$src"
        dest_path="$home_dir/$src"
        ensure_symlink "$src_path" "$dest_path"
    done

    # Fish config: real dir with symlinks to shared files, writable fish_variables
    fish_conf="$home_dir/.config/fish"
    fish_shared="$dotfiles_dir/.config/fish"
    if [ -L "$fish_conf" ]; then
        rm -f "$fish_conf"
    fi
    mkdir -p "$fish_conf"
    for item in config.fish config.fish.gcloud fish_plugins completions conf.d functions; do
        ensure_symlink "$fish_shared/$item" "$fish_conf/$item"
    done
    # fish_variables must be writable per-user (fish stores universal variables here)
    if [ ! -f "$fish_conf/fish_variables" ]; then
        cp "$fish_shared/fish_variables" "$fish_conf/fish_variables" 2>/dev/null || touch "$fish_conf/fish_variables"
    fi
    chown -R "$plesk_user:" "$fish_conf"

    # Helpers symlink
    ensure_symlink "$dotfiles_dir/helpers" "$home_dir/.local/bin/helpers"

    # Fix ownership of user-created dirs/symlinks
    chown -h "$plesk_user:" "$dotfiles_dir" "$omf_data" \
        "$home_dir/.bashrc" "$home_dir/.gitconfig" "$home_dir/.Xresources" \
        "$home_dir/.gitignore" 2>/dev/null || true
    chown -h "$plesk_user:" "$home_dir/.config/.func" "$home_dir/.config/.aliasrc" \
        "$home_dir/.config/tmux" "$home_dir/.local/bin/helpers" 2>/dev/null || true

    ok=$((ok + 1))
done <<< "$plesk_users"

echo ""
print_color bold_green "Done: $ok configured, $skip skipped"
print_color green "  Shared dotfiles:  $(du -sh "$SHARED_DOTFILES" | cut -f1) at $SHARED_DOTFILES"
print_color green "  Shared OMF:       $(du -sh "$SHARED_OMF" | cut -f1) at $SHARED_OMF"
[[ -d "$SHARED_OPENCODE" ]] && \
print_color green "  Shared opencode:  $(du -sh "$SHARED_OPENCODE" | cut -f1) at $SHARED_OPENCODE"
[[ -x "$OC_BIN_DEST" ]] && \
print_color green "  opencode binary:  $OC_BIN_DEST"
