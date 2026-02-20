#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Unified Plesk vhost setup.
# Run as root. Idempotent — first run installs, subsequent runs update/fix.
#
# Usage:
#   plesk-init.sh              Full setup/update (all sections)
#   plesk-init.sh sync         Quick rsync shared data only (no downloads)
#   plesk-init.sh <section>    One of: dotfiles omf opencode vscode nvim bun vhosts
#
# Shared locations (root-owned, world-readable):
#   /opt/dotfiles/            Dotfiles (rsync from /root/dotfiles, no .git)
#   /opt/omf/                 Oh My Fish + bass plugin
#   /opt/opencode-config/     Opencode config (models, skills, MCP plugins)  [psacln-writable]
#   /opt/opencode-cache/      Opencode auth plugins, models.json             [psacln-writable]
#   /opt/opencode-bin/        Opencode LSP servers (intelephense, bash-ls)   [psacln-writable]
#   /opt/vscode-server/       VS Code Server (binaries, extensions, data)    [psacln-writable]
#   /opt/nvim/                Neovim binary
#   /opt/nvim-config/nvim/    Neovim config
#   /opt/nvim-data/nvim/      Lazy plugins, Mason LSPs, Treesitter parsers
#   /var/www/bun-cache/       Shared bun install cache
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/../globals.sh"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

require_root() {
    if [[ $EUID -ne 0 ]]; then
        print_color red "Must run as root"
        exit 1
    fi
}

# Set root:root ownership and world-readable permissions on a directory tree.
lock_perms() {
    local dir="$1"
    chown -R root:root "$dir"
    chmod -R u+rwX,go+rX,go-w "$dir"
}

# Set root:psacln ownership with group-writable SGID on a directory tree.
# Used for shared dirs that vhost users (all in psacln) must write to.
shared_perms() {
    local dir="$1"
    chown -R root:psacln "$dir"
    find "$dir" -type d -exec chmod 2775 {} +
    find "$dir" -type f -exec chmod 664 {} +
}

# Create or update a symlink. No-op if already correct.
ensure_symlink() {
    local src="$1"
    local dest="$2"

    if [[ -L "$dest" ]] && [[ "$(readlink "$dest")" == "$src" ]]; then
        return
    fi

    if [[ -e "$dest" || -L "$dest" ]]; then
        rm -rf "$dest"
    fi

    mkdir -p "$(dirname "$dest")"
    ln -sf "$src" "$dest"
}

# Replace a real directory (or stale symlink) with a symlink.
replace_with_symlink() {
    local target="$1"
    local link="$2"

    if [[ -d "$link" && ! -L "$link" ]]; then
        rm -rf "$link"
    fi
    ensure_symlink "$target" "$link"
}

# Query all Plesk vhost users (domain, login, home).
query_vhosts() {
    plesk db -N -B -e "
        SELECT d.name, s.login, s.home
        FROM domains d
        JOIN hosting h ON d.id = h.dom_id
        JOIN sys_users s ON h.sys_user_id = s.id
        WHERE d.htype = 'vrt_hst'
    " 2>/dev/null || true
}

# Run a headless nvim command with timeout.
nvim_headless() {
    local desc="$1"
    local lua_code="$2"
    local wait="${3:-120}"

    print_color green "$desc"
    timeout "$wait" env XDG_DATA_HOME=/opt/nvim-data \
        /opt/nvim/bin/nvim --headless -c "lua $lua_code" 2>&1 || {
        local rc=$?
        if [[ $rc -eq 124 ]]; then
            print_color yellow "  Timed out after ${wait}s"
        else
            print_color yellow "  Exited with code $rc"
        fi
    }
}

# ---------------------------------------------------------------------------
# Section: dotfiles  (/opt/dotfiles)
# ---------------------------------------------------------------------------

setup_dotfiles() {
    print_color bold_green "=== Dotfiles ==="

    mkdir -p /opt/dotfiles
    rsync -a --delete \
        --exclude='.git' \
        --exclude='tests/' \
        /root/dotfiles/ /opt/dotfiles/
    lock_perms /opt/dotfiles

    print_color green "  /opt/dotfiles synced ($(du -sh /opt/dotfiles | cut -f1))"
}

# ---------------------------------------------------------------------------
# Section: omf  (/opt/omf — Oh My Fish + bass)
# ---------------------------------------------------------------------------

setup_omf() {
    print_color bold_green "=== Oh My Fish ==="

    if [[ -f /opt/omf/init.fish && -d /opt/omf/pkg/bass ]]; then
        print_color green "  OMF already installed"
    else
        print_color green "  Installing OMF + bass..."
        rm -rf /opt/omf

        local installer tmp_conf
        installer=$(mktemp)
        tmp_conf=$(mktemp -d)
        trap 'rm -f "${installer:-}"; rm -rf "${tmp_conf:-}"' RETURN

        curl -sfo "$installer" \
            https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install
        fish "$installer" --noninteractive --path=/opt/omf --config="$tmp_conf"
        fish -c "
            set -gx OMF_PATH /opt/omf
            set -gx OMF_CONFIG $tmp_conf
            source /opt/omf/init.fish
            omf install bass
        "
    fi

    # Strip .git dirs — not needed for read-only shared use
    find /opt/omf -name ".git" -type d -exec rm -rf {} + 2>/dev/null || true
    lock_perms /opt/omf

    print_color green "  /opt/omf ready ($(du -sh /opt/omf | cut -f1))"
}

# ---------------------------------------------------------------------------
# Section: opencode  (/opt/opencode-{config,cache,bin} + /usr/local/bin/opencode)
# ---------------------------------------------------------------------------

# Files excluded from shared config (per-user auth/runtime data).
readonly OPENCODE_EXCLUDES=(
    --exclude='antigravity-accounts.json'
    --exclude='antigravity-accounts.json.*.tmp'
    --exclude='antigravity-signature-cache.json'
    --exclude='antigravity-logs/'
    --exclude='logs/'
)

setup_opencode() {
    print_color bold_green "=== Opencode ==="

    local root_oc="$HOME/.config/opencode"
    if [[ -d "$root_oc" ]]; then
        mkdir -p /opt/opencode-config
        rsync -a --delete "${OPENCODE_EXCLUDES[@]}" \
            "$root_oc/" /opt/opencode-config/
        # Ensure config.json exists (opencode expects it)
        [[ -f /opt/opencode-config/config.json ]] || echo '{}' > /opt/opencode-config/config.json
        shared_perms /opt/opencode-config
        print_color green "  /opt/opencode-config synced ($(du -sh /opt/opencode-config | cut -f1))"
    else
        print_color yellow "  No opencode config at $root_oc — skipping"
    fi

    # Shared cache (auth plugins, models.json — identical across vhosts)
    local root_cache="$HOME/.cache/opencode"
    if [[ -d "$root_cache" ]]; then
        mkdir -p /opt/opencode-cache
        rsync -a --delete "$root_cache/" /opt/opencode-cache/
        shared_perms /opt/opencode-cache
        print_color green "  /opt/opencode-cache synced ($(du -sh /opt/opencode-cache | cut -f1))"
    fi

    # Shared LSP binaries (intelephense, bash-language-server)
    local root_bin="$HOME/.local/share/opencode/bin"
    if [[ -d "$root_bin" ]]; then
        mkdir -p /opt/opencode-bin
        rsync -a --delete "$root_bin/" /opt/opencode-bin/
        shared_perms /opt/opencode-bin
        print_color green "  /opt/opencode-bin synced ($(du -sh /opt/opencode-bin | cut -f1))"
    fi

    # Copy native binary to /usr/local/bin if newer or missing
    local oc_src="$HOME/.bun/install/global/node_modules/opencode-linux-x64/bin/opencode"
    if [[ -x "$oc_src" ]]; then
        if [[ ! -x /usr/local/bin/opencode ]] || [[ "$oc_src" -nt /usr/local/bin/opencode ]]; then
            if cp "$oc_src" /usr/local/bin/opencode 2>/dev/null; then
                chmod 755 /usr/local/bin/opencode
                print_color green "  /usr/local/bin/opencode installed"
            else
                print_color yellow "  /usr/local/bin/opencode busy (in use) — skipped"
            fi
        else
            print_color green "  /usr/local/bin/opencode up to date"
        fi
    fi
}

# ---------------------------------------------------------------------------
# Section: vscode  (/opt/vscode-server)
# ---------------------------------------------------------------------------

setup_vscode() {
    print_color bold_green "=== VS Code Server ==="

    local root_vs="$HOME/.vscode-server"
    local shared="/opt/vscode-server"

    # If root has a real dir (not yet symlinked), merge it into shared
    if [[ -d "$root_vs" && ! -L "$root_vs" ]]; then
        mkdir -p "$shared"/{cli/servers,extensions}

        # Server versions
        for s in "$root_vs"/cli/servers/Stable-*/; do
            [[ -d "$s" ]] || continue
            local name; name=$(basename "$s")
            [[ -d "$shared/cli/servers/$name" ]] || cp -a "$s" "$shared/cli/servers/$name"
        done
        [[ -f "$root_vs/cli/servers/lru.json" ]] && \
            cp -f "$root_vs/cli/servers/lru.json" "$shared/cli/servers/lru.json"

        # Code binaries
        for b in "$root_vs"/code-*; do
            [[ -f "$b" ]] || continue
            local name; name=$(basename "$b")
            [[ -f "$shared/$name" ]] || cp -a "$b" "$shared/$name"
        done

        # Extensions
        if [[ -d "$root_vs/extensions" ]]; then
            rsync -a --ignore-existing "$root_vs/extensions/" "$shared/extensions/"
        fi

        # Data (settings, VSIX cache, logs)
        if [[ -d "$root_vs/data" ]]; then
            rsync -a "$root_vs/data/" "$shared/data/"
        fi

        # CLI config
        rsync -a --ignore-existing "$root_vs/cli/" "$shared/cli/"

        # Replace root dir with symlink
        rm -rf "$root_vs"
        ln -s "$shared" "$root_vs"
        print_color green "  Root .vscode-server merged and symlinked"
    fi

    # Ensure shared dir exists and has correct permissions
    if [[ -d "$shared" ]]; then
        chgrp -R psacln "$shared"
        find "$shared" -type d -exec chmod 2775 {} +
        find "$shared" -type f -exec chmod 664 {} +
        find "$shared" -type f \( -name "code-*" -o -name "code" -o -name "node" \
            -o -name "*.sh" -o -path "*/bin/*" -o -path "*/.bin/*" \) -exec chmod 775 {} +
        print_color green "  /opt/vscode-server ready ($(du -sh "$shared" | cut -f1))"
    else
        print_color yellow "  No VS Code Server found — skipping"
    fi
}

# ---------------------------------------------------------------------------
# Section: nvim  (/opt/nvim, /opt/nvim-config, /opt/nvim-data)
# ---------------------------------------------------------------------------

setup_nvim() {
    print_color bold_green "=== Neovim ==="

    local nvim_bin="/opt/nvim/bin/nvim"

    # --- Binary ---
    if [[ ! -x "$nvim_bin" ]]; then
        print_color green "  Downloading nvim..."
        local tmp
        tmp=$(mktemp -d)
        trap 'rm -rf "${tmp:-}"' RETURN
        curl -fsSL -o "$tmp/nvim.tar.gz" \
            "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"
        rm -rf /opt/nvim
        tar -xzf "$tmp/nvim.tar.gz" -C /opt
        mv /opt/nvim-linux-x86_64 /opt/nvim
    fi
    print_color green "  $($nvim_bin --version | head -1)"

    # --- Wrapper (scopes XDG vars to the nvim process only) ---
    cat > /usr/local/bin/nvim << 'WRAPPER'
#!/bin/bash
if [ "$(id -u)" -ne 0 ] && [ -d /opt/nvim-data/nvim/lazy ]; then
    # Ensure writable dirs exist for plugin state/cache
    mkdir -p "$HOME/.local/state/nvim" "$HOME/.cache/nvim"
    # Only override data/state/cache — config comes from ~/.config/nvim
    # symlink so XDG_CONFIG_HOME stays untouched for child processes (fish etc.)
    exec env \
        XDG_DATA_HOME=/opt/nvim-data \
        XDG_STATE_HOME="$HOME/.local/state" \
        XDG_CACHE_HOME="$HOME/.cache" \
        /opt/nvim/bin/nvim "$@"
fi
exec /opt/nvim/bin/nvim "$@"
WRAPPER
    chmod 755 /usr/local/bin/nvim
    ln -sf /usr/local/bin/nvim /usr/local/bin/vim

    # Redirect any direct binary symlinks through the wrapper
    local link
    for link in /usr/bin/nvim /usr/bin/vim; do
        if [[ -L "$link" ]] && [[ "$(readlink -f "$link")" == "$nvim_bin" ]]; then
            ln -sf /usr/local/bin/nvim "$link"
        fi
    done

    # --- Root config symlink ---
    local nvim_src="$HOME/dotfiles/.config/nvim"
    if [[ -d "$nvim_src" && ! -e "$HOME/.config/nvim" ]]; then
        mkdir -p "$HOME/.config"
        ln -sf "$nvim_src" "$HOME/.config/nvim"
    fi

    # --- Shared config ---
    mkdir -p /opt/nvim-config/nvim
    rsync -a --delete "$nvim_src/" /opt/nvim-config/nvim/
    lock_perms /opt/nvim-config

    # --- Shared data (plugins, LSPs, parsers) ---
    mkdir -p /opt/nvim-data/nvim

    nvim_headless "  Syncing plugins..." \
        "local ok,lazy = pcall(require,'lazy'); if ok then lazy.sync({wait=true}) end; vim.cmd('qa!')"

    nvim_headless "  Installing/updating Mason LSP servers..." "
        local reg = require('mason-registry')
        reg.refresh(function()
            local pkgs = {'lua-language-server','intelephense','json-lsp'}
            local done, total = 0, #pkgs
            local function tick()
                done = done + 1
                if done >= total then vim.schedule(function() vim.cmd('qa!') end) end
            end
            for _, name in ipairs(pkgs) do
                local ok, pkg = pcall(reg.get_package, name)
                if ok and not pkg:is_installed() then
                    pkg:install():on('closed', tick)
                else
                    tick()
                end
            end
        end)
    "

    nvim_headless "  Installing/updating Treesitter parsers..." "
        local langs = {'vimdoc','javascript','typescript','lua','jsdoc','bash','php','fish'}
        for _, l in ipairs(langs) do vim.cmd('TSInstallSync! ' .. l) end
        vim.cmd('qa!')
    "

    # --- Lock data + make mason binaries executable ---
    lock_perms /opt/nvim-data
    find /opt/nvim-data/nvim/mason -type f \( -name "*.sh" -o -path "*/bin/*" \) \
        -exec chmod 755 {} + 2>/dev/null || true

    # Clean stale profile.d script
    rm -f /etc/profile.d/nvim.sh
}

# ---------------------------------------------------------------------------
# Section: bun  (/usr/local/bin/bun*, /var/www/bun-cache)
# ---------------------------------------------------------------------------

setup_bun() {
    print_color bold_green "=== Bun ==="

    # Download latest to a temp dir
    local tmp
    tmp=$(mktemp -d)
    trap 'rm -rf "${tmp:-}"' RETURN

    curl -fsSL https://bun.sh/install | BUN_INSTALL="$tmp" bash >/dev/null 2>&1
    if [[ ! -f "$tmp/bin/bun" ]]; then
        print_color red "  Failed to download bun"
        return 1
    fi

    local new_ver
    new_ver=$("$tmp/bin/bun" --version)

    # Check if update is needed
    if [[ -f /usr/local/bin/bun-bin ]]; then
        local old_ver
        old_ver=$(/usr/local/bin/bun-bin --version 2>/dev/null || echo "unknown")
        if [[ "$old_ver" == "$new_ver" ]]; then
            print_color green "  bun v${new_ver} (up to date)"
        else
            print_color green "  bun v${old_ver} -> v${new_ver}"
        fi
    else
        print_color green "  Installing bun v${new_ver}"
    fi

    # Install binary
    install -m 755 -o root -g root "$tmp/bin/bun" /usr/local/bin/bun-bin

    # --- bun-run helper (called via sudo, runs bun as root for cache writes) ---
    cat > /usr/local/bin/bun-run << 'HELPER'
#!/bin/bash
CALLER_USER="$1"
CALLER_GROUP="$2"
WORK_DIR="$3"
shift 3

export BUN_INSTALL_CACHE_DIR="/var/www/bun-cache"
cd "$WORK_DIR" || exit 1

/usr/local/bin/bun-bin "$@"
status=$?

# Restore ownership of outputs to the calling user
if [[ -d node_modules ]]; then
    chown -R "${CALLER_USER}:${CALLER_GROUP}" node_modules 2>/dev/null &
fi
for f in bun.lock bun.lockb; do
    [[ -f "$f" ]] && chown "${CALLER_USER}:${CALLER_GROUP}" "$f" 2>/dev/null
done

exit $status
HELPER
    chmod 755 /usr/local/bin/bun-run

    # --- bun wrapper ---
    cat > /usr/local/bin/bun << 'WRAPPER'
#!/bin/bash
export BUN_INSTALL_CACHE_DIR="/var/www/bun-cache"
if [[ "$(id -un)" == "root" ]]; then
    exec /usr/local/bin/bun-bin "$@"
else
    exec sudo /usr/local/bin/bun-run "$(id -un)" "$(id -gn)" "$(pwd)" "$@"
fi
WRAPPER
    chmod 755 /usr/local/bin/bun
    ln -sf /usr/local/bin/bun /usr/local/bin/bunx

    # --- Shared cache ---
    mkdir -p /var/www/bun-cache
    chmod 755 /var/www/bun-cache
    if [[ -n "$(ls -A /var/www/bun-cache 2>/dev/null)" ]]; then
        lock_perms /var/www/bun-cache
    fi

    # --- Sudoers ---
    local sudoers="/etc/sudoers.d/bun-cache"
    printf 'ALL ALL=(root) NOPASSWD: /usr/local/bin/bun-run *\n' > "$sudoers"
    chmod 440 "$sudoers"
    if ! visudo -cf "$sudoers" >/dev/null 2>&1; then
        print_color red "  Sudoers syntax check failed"
        rm -f "$sudoers"
        return 1
    fi

    # --- Profile env var ---
    printf 'export BUN_INSTALL_CACHE_DIR="/var/www/bun-cache"\n' > /etc/profile.d/bun.sh
    chmod 644 /etc/profile.d/bun.sh

    print_color green "  bun v$(/usr/local/bin/bun-bin --version) ready"
}

# ---------------------------------------------------------------------------
# Section: vhosts — per-user symlinks, cleanup, and node/php binaries
# ---------------------------------------------------------------------------

# Config files symlinked through ~/dotfiles -> /opt/dotfiles.
readonly VHOST_SYMLINKS=(
    ".bashrc"
    ".gitconfig"
    ".Xresources"
    ".gitignore"
    ".config/.func"
    ".config/.aliasrc"
    ".config/btop/btop.conf"
    ".config/tmux"
)

# Fish config items symlinked inside the per-user ~/.config/fish/ directory.
readonly FISH_SHARED_ITEMS=(
    config.fish
    config.fish.gcloud
    fish_plugins
    completions
    conf.d
    functions
)

# Per-user directories/files left over from old per-user installs.
readonly CLEANUP_DIRS=(
    .local/nvim
    .local/share/nvim
    .cache/nvim
    .bun
)

# Stale opencode per-user dirs replaced by shared symlinks.
# Removed BEFORE creating symlinks so rm -rf doesn't follow them.
readonly OPENCODE_CLEANUP_DIRS=(
    .cache/opencode
    .local/share/opencode/bin
)

setup_vhost_fish() {
    local home_dir="$1"
    local plesk_user="$2"
    local fish_conf="$home_dir/.config/fish"
    local fish_shared="$home_dir/dotfiles/.config/fish"

    # Must be a real dir (not symlink) so fish_variables is writable
    [[ -L "$fish_conf" ]] && rm -f "$fish_conf"
    mkdir -p "$fish_conf"

    local item
    for item in "${FISH_SHARED_ITEMS[@]}"; do
        ensure_symlink "$fish_shared/$item" "$fish_conf/$item"
    done

    # fish_variables stores universal vars — must be per-user writable
    if [[ ! -f "$fish_conf/fish_variables" ]]; then
        cp "$fish_shared/fish_variables" "$fish_conf/fish_variables" 2>/dev/null \
            || touch "$fish_conf/fish_variables"
    fi

    chown -R "$plesk_user:" "$fish_conf"
}

setup_vhost_omf() {
    local home_dir="$1"
    local plesk_user="$2"

    replace_with_symlink /opt/omf "$home_dir/.local/share/omf"

    # OMF config is per-user writable (theme, channel, bundle)
    if [[ ! -d "$home_dir/.config/omf" ]]; then
        mkdir -p "$home_dir/.config/omf"
        printf 'package bass\n' > "$home_dir/.config/omf/bundle"
        printf 'default\n'      > "$home_dir/.config/omf/theme"
        printf 'default\n'      > "$home_dir/.config/omf/channel"
        chown -R "$plesk_user:" "$home_dir/.config/omf"
    fi
}

setup_vhost_plesk_bins() {
    local home_dir="$1"
    local bin_dir="$home_dir/.local/bin"
    local node_ver php_ver

    node_ver=$(ls -1 /opt/plesk/node/ 2>/dev/null | sort -V | tail -1)
    php_ver=$(ls -1 /opt/plesk/php/ 2>/dev/null | sort -V | tail -1)

    local src_dir bin
    for src_dir in "/opt/plesk/node/${node_ver}/bin" "/opt/plesk/php/${php_ver}/bin"; do
        [[ -d "$src_dir" ]] || continue
        for bin in "$src_dir"/*; do
            [[ -f "$bin" ]] || continue
            [[ -e "$bin_dir/$(basename "$bin")" ]] || ln -sf "$bin" "$bin_dir/"
        done
    done
}

setup_vhosts() {
    print_color bold_green "=== Vhost users ==="

    local plesk_users
    plesk_users=$(query_vhosts)
    if [[ -z "$plesk_users" ]]; then
        print_color yellow "  No Plesk users found"
        return
    fi

    local ok=0 skip=0
    local domain plesk_user home_dir
    while IFS=$'\t' read -r domain plesk_user home_dir; do
        [[ -z "$domain" || -z "$plesk_user" || -z "$home_dir" ]] && continue

        if ! id "$plesk_user" &>/dev/null || [[ ! -d "$home_dir" ]]; then
            skip=$((skip + 1))
            continue
        fi

        print_color green "  $plesk_user ($domain)"
        local dotfiles_dir="$home_dir/dotfiles"

        # Dotfiles: replace per-user clone with symlink to shared
        replace_with_symlink /opt/dotfiles "$dotfiles_dir"

        # Ensure base directories exist
        mkdir -p \
            "$home_dir/.config" \
            "$home_dir/.local/bin" \
            "$home_dir/.local/share"

        # Config symlinks
        local src
        for src in "${VHOST_SYMLINKS[@]}"; do
            ensure_symlink "$dotfiles_dir/$src" "$home_dir/$src"
        done
        ensure_symlink "$dotfiles_dir/helpers" "$home_dir/.local/bin/helpers"

        # Per-tool setup
        setup_vhost_fish "$home_dir" "$plesk_user"
        setup_vhost_omf  "$home_dir" "$plesk_user"

        # Cleanup stale per-user installs (must run before creating dirs/symlinks)
        local d
        for d in "${CLEANUP_DIRS[@]}"; do
            [[ -d "$home_dir/$d" ]] && rm -rf "${home_dir:?}/$d"
        done
        for d in "${OPENCODE_CLEANUP_DIRS[@]}"; do
            [[ -d "$home_dir/$d" && ! -L "$home_dir/$d" ]] && rm -rf "${home_dir:?}/$d"
        done

        # Opencode: shared config, cache, and LSP binaries
        if [[ -d /opt/opencode-config ]]; then
            replace_with_symlink /opt/opencode-config "$home_dir/.config/opencode"
            chown -h "$plesk_user:" "$home_dir/.config/opencode" 2>/dev/null || true
        fi
        if [[ -d /opt/opencode-cache ]]; then
            mkdir -p "$home_dir/.cache"
            replace_with_symlink /opt/opencode-cache "$home_dir/.cache/opencode"
            chown -h "$plesk_user:" "$home_dir/.cache/opencode" 2>/dev/null || true
        fi
        if [[ -d /opt/opencode-bin ]]; then
            mkdir -p "$home_dir/.local/share/opencode"
            replace_with_symlink /opt/opencode-bin "$home_dir/.local/share/opencode/bin"
            chown -h "$plesk_user:" "$home_dir/.local/share/opencode/bin" 2>/dev/null || true
            chown "$plesk_user:" "$home_dir/.local/share/opencode" 2>/dev/null || true
        fi

        # VS Code Server
        if [[ -d /opt/vscode-server ]]; then
            replace_with_symlink /opt/vscode-server "$home_dir/.vscode-server"
            chown -h "$plesk_user:" "$home_dir/.vscode-server" 2>/dev/null || true
        fi

        # Nvim config: symlink so nvim finds shared config without overriding XDG_CONFIG_HOME
        replace_with_symlink /opt/nvim-config/nvim "$home_dir/.config/nvim"

        # Writable nvim state/cache dirs (created after cleanup so they survive)
        mkdir -p \
            "$home_dir/.local/state/nvim" \
            "$home_dir/.cache/nvim"

        # Plesk node/php binaries
        setup_vhost_plesk_bins "$home_dir"

        # Fix ownership on writable dirs
        chown -R "$plesk_user:" \
            "$home_dir/.local/state" \
            "$home_dir/.cache/nvim" \
            2>/dev/null || true

        # Fix symlink ownership
        chown -h "$plesk_user:" \
            "$dotfiles_dir" \
            "$home_dir/.local/share/omf" \
            "$home_dir/.bashrc" \
            "$home_dir/.gitconfig" \
            "$home_dir/.Xresources" \
            "$home_dir/.gitignore" \
            "$home_dir/.config/.func" \
            "$home_dir/.config/.aliasrc" \
            "$home_dir/.config/tmux" \
            "$home_dir/.config/nvim" \
            "$home_dir/.local/bin/helpers" \
            2>/dev/null || true

        ok=$((ok + 1))
    done <<< "$plesk_users"

    print_color green "  $ok configured, $skip skipped"
}

# ---------------------------------------------------------------------------
# Composite commands
# ---------------------------------------------------------------------------

# Quick sync: rsync shared data without downloading/installing anything.
do_sync() {
    print_color bold_green "=== Quick sync ==="

    setup_dotfiles

    if [[ -d /opt/nvim-config/nvim ]]; then
        rsync -a --delete "$HOME/dotfiles/.config/nvim/" /opt/nvim-config/nvim/
        lock_perms /opt/nvim-config
        print_color green "  /opt/nvim-config synced"
    fi

    setup_opencode
    setup_vscode
    print_color bold_green "Sync complete"
}

# Full setup: install/update everything, then configure all vhosts.
do_all() {
    setup_dotfiles
    setup_omf
    setup_opencode
    setup_vscode
    setup_nvim
    setup_bun
    setup_vhosts

    echo ""
    print_color bold_green "=== Setup complete ==="
    printf "  %-24s %s\n" "/opt/dotfiles"        "$(du -sh /opt/dotfiles 2>/dev/null | cut -f1)"
    printf "  %-24s %s\n" "/opt/omf"             "$(du -sh /opt/omf 2>/dev/null | cut -f1)"
    printf "  %-24s %s\n" "/opt/nvim-data"       "$(du -sh /opt/nvim-data 2>/dev/null | cut -f1)"
    printf "  %-24s %s\n" "/var/www/bun-cache"   "$(du -sh /var/www/bun-cache 2>/dev/null | cut -f1)"
    [[ -d /opt/opencode-config ]] && \
        printf "  %-24s %s\n" "/opt/opencode-config" "$(du -sh /opt/opencode-config 2>/dev/null | cut -f1)"
    [[ -d /opt/opencode-cache ]] && \
        printf "  %-24s %s\n" "/opt/opencode-cache"  "$(du -sh /opt/opencode-cache 2>/dev/null | cut -f1)"
    [[ -d /opt/opencode-bin ]] && \
        printf "  %-24s %s\n" "/opt/opencode-bin"    "$(du -sh /opt/opencode-bin 2>/dev/null | cut -f1)"
    [[ -d /opt/vscode-server ]] && \
        printf "  %-24s %s\n" "/opt/vscode-server"   "$(du -sh /opt/vscode-server 2>/dev/null | cut -f1)"
    printf "  %-24s %s\n" "nvim" "$(/opt/nvim/bin/nvim --version 2>/dev/null | head -1)"
    printf "  %-24s %s\n" "bun"  "v$(/usr/local/bin/bun-bin --version 2>/dev/null)"
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

usage() {
    cat <<EOF
Usage: $(basename "$0") [command]

Commands:
  all       Full setup/update (default)
  sync      Quick rsync of shared data (no downloads)
  dotfiles  Sync /root/dotfiles -> /opt/dotfiles
  omf       Install/update shared Oh My Fish + bass
  opencode  Sync opencode config + binary
  vscode    Sync VS Code Server (merge root -> shared)
  nvim      Install/update nvim, plugins, LSPs, parsers
  bun       Install/update bun with shared cache
  vhosts    Configure all vhost user symlinks + cleanup
EOF
}

require_root

case "${1:-all}" in
    all)      do_all ;;
    sync)     do_sync ;;
    dotfiles) setup_dotfiles ;;
    omf)      setup_omf ;;
    opencode) setup_opencode ;;
    vscode)   setup_vscode ;;
    nvim)     setup_nvim ;;
    bun)      setup_bun ;;
    vhosts)   setup_vhosts ;;
    -h|--help|help) usage ;;
    *) usage; exit 1 ;;
esac
