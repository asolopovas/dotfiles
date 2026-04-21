#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/../globals.sh"

require_root() {
    if [[ $EUID -ne 0 ]]; then
        print_color red "Must run as root"
        exit 1
    fi
}

lock_perms() {
    local dir="$1"
    chown -R root:root "$dir"
    chmod -R u+rwX,go+rX,go-w "$dir"
}

shared_perms() {
    local dir="$1"
    chown -R root:psacln "$dir"
    find "$dir" -type d -exec chmod 2775 {} +
    find "$dir" -type f -exec chmod 664 {} +
}

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

replace_with_symlink() {
    local target="$1"
    local link="$2"

    if [[ -d "$link" && ! -L "$link" ]]; then
        rm -rf "$link"
    fi
    ensure_symlink "$target" "$link"
}

query_vhosts() {
    plesk db -N -B -e "
        SELECT d.name, s.login, s.home
        FROM domains d
        JOIN hosting h ON d.id = h.dom_id
        JOIN sys_users s ON h.sys_user_id = s.id
        WHERE d.htype = 'vrt_hst'
    " 2>/dev/null || true
}

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

setup_dotfiles() {
    print_color bold_green "=== Dotfiles ==="

    # /opt/dotfiles IS the canonical git repo; /root/dotfiles is a symlink to it.
    if [[ -d /root/dotfiles && ! -L /root/dotfiles ]]; then
        # Migration: move the real repo to /opt and replace with symlink
        rm -rf /opt/dotfiles
        mv /root/dotfiles /opt/dotfiles
        ln -sf /opt/dotfiles /root/dotfiles
        print_color green "  Migrated /root/dotfiles -> /opt/dotfiles"
    elif [[ ! -d /opt/dotfiles ]]; then
        git clone "$DOTFILES_URL" /opt/dotfiles
        ln -sf /opt/dotfiles /root/dotfiles
    else
        git -C /opt/dotfiles pull --ff-only 2>/dev/null || true
    fi

    # Wire root's dotfiles the same way as vhosts
    local src
    for src in "${VHOST_SYMLINKS[@]}"; do
        ensure_symlink "/root/dotfiles/$src" "/root/$src"
    done
    ensure_symlink "/root/dotfiles/helpers" "/root/.local/bin/helpers"

    lock_perms /opt/dotfiles

    print_color green "  /opt/dotfiles ready ($(du -sh /opt/dotfiles | cut -f1))"
}

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

    find /opt/omf -name ".git" -type d -exec rm -rf {} + 2>/dev/null || true
    lock_perms /opt/omf

    print_color green "  /opt/omf ready ($(du -sh /opt/omf | cut -f1))"
}

readonly OPENCODE_EXCLUDES=(
    --exclude='antigravity-accounts.json'
    --exclude='antigravity-accounts.json.*.tmp'
    --exclude='antigravity-signature-cache.json'
    --exclude='antigravity-logs/'
    --exclude='logs/'
)

setup_opencode() {
    print_color bold_green "=== Opencode ==="

    local sync_ai="${SCRIPT_DIR}/sync-ai.sh"
    if [[ -x "$sync_ai" ]]; then
        print_color green "  Syncing skills via sync-ai.sh..."
        SYNC_TARGETS=opencode "$sync_ai" skills 2>&1 | sed 's/^/    /'
    fi

    local root_oc="$HOME/.config/opencode"
    local agents_skills="${AGENTS_SKILLS_DIR:-$HOME/.agents/skills}"
    if [[ -d "$agents_skills" ]]; then
        mkdir -p "$root_oc/skills"
        rsync -a --delete "$agents_skills/" "$root_oc/skills/"
    fi

    if [[ -d "$root_oc" ]]; then
        mkdir -p /opt/opencode-config
        find /opt/opencode-config -maxdepth 1 -type l -delete 2>/dev/null || true
        rsync -aL --delete "${OPENCODE_EXCLUDES[@]}" \
            "$root_oc/" /opt/opencode-config/
        shared_perms /opt/opencode-config
        chmod +t /opt/opencode-config
        print_color green "  /opt/opencode-config synced ($(du -sh /opt/opencode-config | cut -f1))"
    else
        print_color yellow "  No opencode config at $root_oc — skipping"
    fi

    local root_cache="$HOME/.cache/opencode"
    if [[ -d "$root_cache" ]]; then
        mkdir -p /opt/opencode-cache
        rsync -a --delete "$root_cache/" /opt/opencode-cache/
        shared_perms /opt/opencode-cache
        print_color green "  /opt/opencode-cache synced ($(du -sh /opt/opencode-cache | cut -f1))"
    fi

    local root_bin="$HOME/.local/share/opencode/bin"
    if [[ -d "$root_bin" ]]; then
        mkdir -p /opt/opencode-bin
        rsync -a --delete "$root_bin/" /opt/opencode-bin/
        shared_perms /opt/opencode-bin
        print_color green "  /opt/opencode-bin synced ($(du -sh /opt/opencode-bin | cut -f1))"
    fi

    local oc_src="$HOME/.bun/install/global/node_modules/opencode-linux-x64/bin/opencode"
    if [[ -x "$oc_src" ]]; then
        if [[ ! -x /usr/local/bin/opencode-bin ]] || ! cmp -s "$oc_src" /usr/local/bin/opencode-bin; then
            if cp "$oc_src" /usr/local/bin/opencode-bin 2>/dev/null; then
                chmod 755 /usr/local/bin/opencode-bin
                print_color green "  /usr/local/bin/opencode-bin installed (v$("$oc_src" --version 2>/dev/null))"
            else
                print_color yellow "  /usr/local/bin/opencode-bin busy (in use) — skipped"
            fi
        else
            print_color green "  /usr/local/bin/opencode-bin up to date"
        fi
    fi

    cat >/usr/local/bin/opencode <<'WRAPPER'
#!/bin/bash
exec /usr/local/bin/opencode-bin "$@"
WRAPPER
    chmod 755 /usr/local/bin/opencode

    local bun_link="$HOME/.bun/bin/opencode"
    local bun_shim="$HOME/.bun/install/global/node_modules/opencode-ai/bin/opencode"
    if [[ -e "$bun_link" ]]; then
        rm -f "$bun_link"
        cat >"$bun_link" <<ROOTWRAPPER
#!/bin/bash
OC_BIN="/usr/local/bin/opencode-bin"
OC_BUN_SHIM="$bun_shim"
OC_BUN_SRC="$HOME/.bun/install/global/node_modules/opencode-linux-x64/bin/opencode"

if [[ "\${1:-}" == "upgrade" ]]; then
    "\$OC_BUN_SHIM" "\$@"
    status=\$?
    if [[ \$status -eq 0 && -x "\$OC_BUN_SRC" ]]; then
        if ! cmp -s "\$OC_BUN_SRC" "\$OC_BIN" 2>/dev/null; then
            cp "\$OC_BUN_SRC" "\$OC_BIN" 2>/dev/null && chmod 755 "\$OC_BIN" \
                && echo "Shared binary updated: \$(\$OC_BIN --version 2>/dev/null)"
        fi
    fi
    exit \$status
fi

exec "\$OC_BIN" "\$@"
ROOTWRAPPER
        chmod 755 "$bun_link"
        print_color green "  ~/.bun/bin/opencode wrapper installed (upgrade syncs to shared)"
    fi
}

setup_claude() {
    print_color bold_green "=== Claude Code ==="

    local sync_ai="${SCRIPT_DIR}/sync-ai.sh"
    if [[ -x "$sync_ai" ]]; then
        print_color green "  Syncing skills via sync-ai.sh..."
        SYNC_TARGETS=claude "$sync_ai" skills 2>&1 | sed 's/^/    /'
    fi

    local root_skills="$HOME/.agents/skills"
    if [[ -d "$root_skills" ]]; then
        mkdir -p /opt/agents-skills
        rsync -a --delete "$root_skills/" /opt/agents-skills/
        lock_perms /opt/agents-skills
        print_color green "  /opt/agents-skills synced ($(du -sh /opt/agents-skills | cut -f1))"
    fi

    ensure_symlink /opt/agents-skills "$HOME/.claude/skills"

    print_color green "  Claude config at /opt/dotfiles/.claude/"
}

setup_vscode() {
    print_color bold_green "=== VS Code Server ==="

    local root_vs="$HOME/.vscode-server"
    local shared="/opt/vscode-server"

    if [[ -d "$root_vs" && ! -L "$root_vs" ]]; then
        mkdir -p "$shared"/{cli/servers,extensions}

        for s in "$root_vs"/cli/servers/Stable-*/; do
            [[ -d "$s" ]] || continue
            local name
            name=$(basename "$s")
            [[ -d "$shared/cli/servers/$name" ]] || cp -a "$s" "$shared/cli/servers/$name"
        done
        [[ -f "$root_vs/cli/servers/lru.json" ]] &&
            cp -f "$root_vs/cli/servers/lru.json" "$shared/cli/servers/lru.json"

        for b in "$root_vs"/code-*; do
            [[ -f "$b" ]] || continue
            local name
            name=$(basename "$b")
            [[ -f "$shared/$name" ]] || cp -a "$b" "$shared/$name"
        done

        if [[ -d "$root_vs/extensions" ]]; then
            rsync -a --ignore-existing "$root_vs/extensions/" "$shared/extensions/"
        fi

        if [[ -d "$root_vs/data" ]]; then
            rsync -a "$root_vs/data/" "$shared/data/"
        fi

        rsync -a --ignore-existing "$root_vs/cli/" "$shared/cli/"

        rm -rf "$root_vs"
        ln -s "$shared" "$root_vs"
        print_color green "  Root .vscode-server merged and symlinked"
    fi

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

setup_nvim() {
    print_color bold_green "=== Neovim ==="

    local nvim_bin="/opt/nvim/bin/nvim"

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

    cat >/usr/local/bin/nvim <<'WRAPPER'
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

    local link
    for link in /usr/bin/nvim /usr/bin/vim; do
        if [[ -L "$link" ]] && [[ "$(readlink -f "$link")" == "$nvim_bin" ]]; then
            ln -sf /usr/local/bin/nvim "$link"
        fi
    done

    local nvim_src="$HOME/dotfiles/.config/nvim"
    if [[ -d "$nvim_src" && ! -e "$HOME/.config/nvim" ]]; then
        mkdir -p "$HOME/.config"
        ln -sf "$nvim_src" "$HOME/.config/nvim"
    fi

    mkdir -p /opt/nvim-config/nvim
    rsync -a --delete "$nvim_src/" /opt/nvim-config/nvim/
    lock_perms /opt/nvim-config

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

    lock_perms /opt/nvim-data
    find /opt/nvim-data/nvim/mason -type f \( -name "*.sh" -o -path "*/bin/*" \) \
        -exec chmod 755 {} + 2>/dev/null || true

    rm -f /etc/profile.d/nvim.sh
}

setup_bun() {
    print_color bold_green "=== Bun ==="

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

    install -m 755 -o root -g root "$tmp/bin/bun" /usr/local/bin/bun-bin

    cat >/usr/local/bin/bun-run <<'HELPER'
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

    cat >/usr/local/bin/bun <<'WRAPPER'
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

    mkdir -p /var/www/bun-cache
    chmod 755 /var/www/bun-cache
    if [[ -n "$(ls -A /var/www/bun-cache 2>/dev/null)" ]]; then
        lock_perms /var/www/bun-cache
    fi

    local sudoers="/etc/sudoers.d/bun-cache"
    printf 'ALL ALL=(root) NOPASSWD: /usr/local/bin/bun-run *\n' >"$sudoers"
    chmod 440 "$sudoers"
    if ! visudo -cf "$sudoers" >/dev/null 2>&1; then
        print_color red "  Sudoers syntax check failed"
        rm -f "$sudoers"
        return 1
    fi

    printf 'export BUN_INSTALL_CACHE_DIR="/var/www/bun-cache"\n' >/etc/profile.d/bun.sh
    chmod 644 /etc/profile.d/bun.sh

    print_color green "  bun v$(/usr/local/bin/bun-bin --version) ready"
}

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

readonly FISH_SHARED_ITEMS=(
    config.fish
    config.fish.gcloud
    fish_plugins
    completions
    conf.d
    functions
)

readonly CLEANUP_DIRS=(
    .local/nvim
    .local/share/nvim
    .cache/nvim
    .bun
)

readonly OPENCODE_CLEANUP_DIRS=(
    .opencode
    .cache/opencode
    .local/share/opencode/bin
)

setup_vhost_fish() {
    local home_dir="$1"
    local plesk_user="$2"
    local fish_conf="$home_dir/.config/fish"
    local fish_shared="$home_dir/dotfiles/.config/fish"

    [[ -L "$fish_conf" ]] && rm -f "$fish_conf"
    mkdir -p "$fish_conf"

    local item
    for item in "${FISH_SHARED_ITEMS[@]}"; do
        ensure_symlink "$fish_shared/$item" "$fish_conf/$item"
    done

    if [[ ! -f "$fish_conf/fish_variables" ]]; then
        cp "$fish_shared/fish_variables" "$fish_conf/fish_variables" 2>/dev/null ||
            touch "$fish_conf/fish_variables"
    fi

    chown -R "$plesk_user:" "$fish_conf"
}

setup_vhost_omf() {
    local home_dir="$1"
    local plesk_user="$2"

    replace_with_symlink /opt/omf "$home_dir/.local/share/omf"

    if [[ ! -d "$home_dir/.config/omf" ]]; then
        mkdir -p "$home_dir/.config/omf"
        printf 'package bass\n' >"$home_dir/.config/omf/bundle"
        printf 'default\n' >"$home_dir/.config/omf/theme"
        printf 'default\n' >"$home_dir/.config/omf/channel"
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

        replace_with_symlink /opt/dotfiles "$dotfiles_dir"

        mkdir -p \
            "$home_dir/.config" \
            "$home_dir/.local/bin" \
            "$home_dir/.local/share"

        local src
        for src in "${VHOST_SYMLINKS[@]}"; do
            ensure_symlink "$dotfiles_dir/$src" "$home_dir/$src"
        done
        ensure_symlink "$dotfiles_dir/helpers" "$home_dir/.local/bin/helpers"

        setup_vhost_fish "$home_dir" "$plesk_user"
        setup_vhost_omf "$home_dir" "$plesk_user"

        local d
        for d in "${CLEANUP_DIRS[@]}"; do
            [[ -d "$home_dir/$d" ]] && rm -rf "${home_dir:?}/$d"
        done
        for d in "${OPENCODE_CLEANUP_DIRS[@]}"; do
            [[ -d "$home_dir/$d" && ! -L "$home_dir/$d" ]] && rm -rf "${home_dir:?}/$d"
        done

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

        if [[ -d /opt/vscode-server ]]; then
            replace_with_symlink /opt/vscode-server "$home_dir/.vscode-server"
            chown -h "$plesk_user:" "$home_dir/.vscode-server" 2>/dev/null || true
        fi

        replace_with_symlink /opt/nvim-config/nvim "$home_dir/.config/nvim"

        # Claude
        mkdir -p "$home_dir/.claude"
        ensure_symlink "$dotfiles_dir/.claude/settings.json" "$home_dir/.claude/settings.json"
        rm -f "$home_dir/.claude/commands" 2>/dev/null || true
        if [[ -d /opt/agents-skills ]]; then
            replace_with_symlink /opt/agents-skills "$home_dir/.claude/skills"
        fi

        mkdir -p \
            "$home_dir/.local/state/nvim" \
            "$home_dir/.cache/nvim"

        setup_vhost_plesk_bins "$home_dir"

        chown -R "$plesk_user:" \
            "$home_dir/.local/state" \
            "$home_dir/.cache/nvim" \
            2>/dev/null || true

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
            "$home_dir/.claude/settings.json" \
            "$home_dir/.claude/skills" \
            "$home_dir/.local/bin/helpers" \
            2>/dev/null || true

        ok=$((ok + 1))
    done <<<"$plesk_users"

    print_color green "  $ok configured, $skip skipped"
}

do_sync() {
    print_color bold_green "=== Quick sync ==="

    setup_dotfiles
    setup_vhosts

    if [[ -d /opt/nvim-config/nvim ]]; then
        rsync -a --delete /opt/dotfiles/.config/nvim/ /opt/nvim-config/nvim/
        lock_perms /opt/nvim-config
        print_color green "  /opt/nvim-config synced"
    fi

    setup_opencode
    setup_claude
    setup_vscode
    print_color bold_green "Sync complete"
}

do_all() {
    setup_dotfiles
    setup_omf
    setup_opencode
    setup_claude
    setup_vscode
    setup_nvim
    setup_bun
    setup_vhosts

    echo ""
    print_color bold_green "=== Setup complete ==="
    printf "  %-24s %s\n" "/opt/dotfiles" "$(du -sh /opt/dotfiles 2>/dev/null | cut -f1)"
    printf "  %-24s %s\n" "/opt/omf" "$(du -sh /opt/omf 2>/dev/null | cut -f1)"
    printf "  %-24s %s\n" "/opt/nvim-data" "$(du -sh /opt/nvim-data 2>/dev/null | cut -f1)"
    printf "  %-24s %s\n" "/var/www/bun-cache" "$(du -sh /var/www/bun-cache 2>/dev/null | cut -f1)"
    [[ -d /opt/opencode-config ]] &&
        printf "  %-24s %s\n" "/opt/opencode-config" "$(du -sh /opt/opencode-config 2>/dev/null | cut -f1)"
    [[ -d /opt/opencode-cache ]] &&
        printf "  %-24s %s\n" "/opt/opencode-cache" "$(du -sh /opt/opencode-cache 2>/dev/null | cut -f1)"
    [[ -d /opt/opencode-bin ]] &&
        printf "  %-24s %s\n" "/opt/opencode-bin" "$(du -sh /opt/opencode-bin 2>/dev/null | cut -f1)"
    [[ -d /opt/vscode-server ]] &&
        printf "  %-24s %s\n" "/opt/vscode-server" "$(du -sh /opt/vscode-server 2>/dev/null | cut -f1)"
    printf "  %-24s %s\n" "nvim" "$(/opt/nvim/bin/nvim --version 2>/dev/null | head -1)"
    printf "  %-24s %s\n" "bun" "v$(/usr/local/bin/bun-bin --version 2>/dev/null)"
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [command]

Commands:
  all       Full setup/update (default)
  sync      Quick rsync of shared data (no downloads)
  dotfiles  Ensure /opt/dotfiles is canonical, wire root symlinks
  omf       Install/update shared Oh My Fish + bass
  opencode  Sync opencode config + binary
  vscode    Sync VS Code Server (merge root -> shared)
  claude    Sync Claude Code config + shared skills
  nvim      Install/update nvim, plugins, LSPs, parsers
  bun       Install/update bun with shared cache
  vhosts    Configure all vhost user symlinks + cleanup
EOF
}

require_root

case "${1:-all}" in
    all) do_all ;;
    sync) do_sync ;;
    dotfiles) setup_dotfiles ;;
    omf) setup_omf ;;
    opencode) setup_opencode ;;
    claude) setup_claude ;;
    vscode) setup_vscode ;;
    nvim) setup_nvim ;;
    bun) setup_bun ;;
    vhosts) setup_vhosts ;;
    -h | --help | help) usage ;;
    *)
        usage
        exit 1
        ;;
esac
