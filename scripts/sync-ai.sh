#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
DOTFILES_AGENTS_DIR="${DOTFILES_AGENTS_DIR:-$DOTFILES_DIR/.agents}"
AGENTS_DIR="${AGENTS_DIR:-$HOME/.agents}"
WINDOWS_AGENTS_DIR="${WINDOWS_AGENTS_DIR:-}"
PLESK_VHOSTS_DIR="${PLESK_VHOSTS_DIR:-/var/www/vhosts}"

CONFIG_LINKS=(
    ".claude/settings.json"
    ".config/opencode/opencode.jsonc"
    ".pi/agent/settings.json"
    ".pi/agent/npm/package.json"
)

CONFIG_DIRS=(
    ".pi/agent/prompts"
)

SKILL_LINKS=(
    ".claude/skills"
    ".codex/skills"
)

PLESK_CONFIG_LINKS=(
    ".claude/settings.json"
    ".pi/agent/settings.json"
)

PLESK_CLAUDE_DIR="${PLESK_CLAUDE_DIR:-/opt/claude}"
PLESK_CLAUDE_BIN="${PLESK_CLAUDE_BIN:-/usr/local/bin/claude}"
PLESK_CLAUDE_GROUP="${PLESK_CLAUDE_GROUP:-}"

PLESK_GRAPHIFY_DIR="${PLESK_GRAPHIFY_DIR:-/opt/graphify}"
PLESK_GRAPHIFY_BIN="${PLESK_GRAPHIFY_BIN:-/usr/local/bin/graphify}"

PLESK_COPY_CONFIGS=(
    ".pi/agent/npm/package.json"
)

PLESK_DIR_LINKS=(
    ".config/opencode"
    ".pi/agent/prompts"
)

die() {
    echo "Error: $*" >&2
    exit 1
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

is_wsl() {
    [[ -n "${WSL_DISTRO_NAME:-}" ]] && return 0
    [[ -r /proc/version ]] && grep -qi microsoft /proc/version
}

ensure_parent() {
    mkdir -p "$(dirname "$1")"
}

backup_path() {
    local path="$1" backup
    backup="$path.backup.$(date +%Y%m%d%H%M%S)"

    while [[ -e "$backup" || -L "$backup" ]]; do
        backup="$path.backup.$(date +%Y%m%d%H%M%S).$$"
    done

    mv "$path" "$backup"
    echo "-> backup: $path -> $backup"
}

replace_with_symlink() {
    local src="$1" dst="$2"

    [[ -e "$src" ]] || die "source does not exist: $src"

    if [[ -L "$dst" ]]; then
        [[ "$(readlink "$dst")" == "$src" ]] && return 0
        rm -f "$dst"
    elif [[ -e "$dst" ]]; then
        if [[ -d "$dst" && -z "$(find "$dst" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
            rmdir "$dst"
        else
            die "$dst exists and is not an empty directory or symlink"
        fi
    fi

    ensure_parent "$dst"
    ln -s "$src" "$dst"
    echo "-> symlink: $dst -> $src"
}

replace_path_with_symlink() {
    local src="$1" dst="$2"

    [[ -e "$src" ]] || die "source does not exist: $src"

    if [[ -L "$dst" ]]; then
        [[ "$(readlink "$dst")" == "$src" ]] && return 0
        rm -f "$dst"
    elif [[ -e "$dst" ]]; then
        if [[ -d "$dst" && -z "$(find "$dst" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
            rmdir "$dst"
        else
            backup_path "$dst"
        fi
    fi

    ensure_parent "$dst"
    ln -s "$src" "$dst"
    echo "-> symlink: $dst -> $src"
}

replace_config_with_symlink() {
    local src="$1" dst="$2"

    [[ -e "$src" ]] || die "source does not exist: $src"

    if [[ -L "$dst" ]]; then
        [[ "$(readlink "$dst")" == "$src" ]] && return 0
        rm -f "$dst"
    elif [[ -e "$dst" ]]; then
        if [[ -d "$dst" && -z "$(find "$dst" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
            rmdir "$dst"
        elif [[ -f "$dst" ]]; then
            if cmp -s "$src" "$dst"; then
                rm -f "$dst"
            else
                backup_path "$dst"
            fi
        else
            die "$dst exists and cannot be replaced safely"
        fi
    fi

    ensure_parent "$dst"
    ln -s "$src" "$dst"
    echo "-> symlink: $dst -> $src"
}

sync_config_file() {
    local src="$1" dst="$2"

    [[ -e "$src" ]] || die "source does not exist: $src"

    if [[ -L "$dst" || -e "$dst" ]]; then
        if [[ -f "$dst" || -L "$dst" ]]; then
            cmp -s "$src" "$dst" && return 0
            backup_path "$dst"
        elif [[ -d "$dst" && -z "$(find "$dst" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
            rmdir "$dst"
        else
            die "$dst exists and cannot be replaced safely"
        fi
    fi

    ensure_parent "$dst"
    cp "$src" "$dst"
    echo "-> copy: $src -> $dst"
}

ensure_user_config_copy() {
    local src="$1" dst="$2" owner="${3:-}"

    [[ -e "$src" ]] || die "source does not exist: $src"

    if [[ -L "$dst" ]]; then
        rm -f "$dst"
    elif [[ -e "$dst" && ! -f "$dst" ]]; then
        backup_path "$dst"
    fi

    if [[ ! -f "$dst" ]]; then
        ensure_parent "$dst"
        cp "$src" "$dst"
        echo "-> copy: $src -> $dst"
    fi

    if [[ -n "$owner" ]]; then
        chown "$owner:" "$dst" 2>/dev/null || true
    fi
    chmod u+rw,go+r "$dst" 2>/dev/null || true
}

sync_directory() {
    local src="$1" dst="$2" parent

    [[ -d "$src" ]] || die "source does not exist: $src"
    parent="$(dirname "$dst")"

    if have_cmd rsync; then
        mkdir -p "$dst"
        rsync -a --delete "$src/" "$dst/"
    else
        rm -rf "$dst"
        mkdir -p "$parent"
        cp -a "$src" "$dst"
    fi
    echo "-> synced directory: $src -> $dst"
}

npm_install_prefix() {
    local prefix="$1" output status

    output=$(mktemp "${TMPDIR:-/tmp}/sync-ai-npm.XXXXXX") || return 1
    if npm install --prefix "$prefix" >"$output" 2>&1; then
        cat "$output"
        rm -f "$output"
        return 0
    fi
    status=$?

    if grep -q 'ERR_INVALID_ARG_TYPE' "$output" && grep -q 'The "from" argument must be of type string' "$output"; then
        echo "-> npm install retry: rebuilding $prefix" >&2
        rm -rf "$prefix/node_modules" "$prefix/package-lock.json"
        rm -f "$output"
        npm install --prefix "$prefix"
        return $?
    fi

    cat "$output" >&2
    rm -f "$output"
    return "$status"
}

sync_linux_npm_packages() {
    local prefix="$HOME/.pi/agent/npm"

    [[ -d "$prefix/node_modules" ]] || return 0
    have_cmd npm || return 0
    npm_install_prefix "$prefix"
}

sync_linux_pi_packages() {
    local prefix="$HOME/.pi/agent"

    [[ -d "$prefix/npm/node_modules" || -d "$prefix/git" ]] || return 0
    have_cmd pi || return 0
    pi update --extensions
}

sync_windows_npm_packages() {
    is_wsl || return 0
    have_cmd powershell.exe || return 0
    have_cmd wslpath || return 0

    local home_dir prefix win_prefix
    home_dir=$(windows_home_dir) || return 0
    prefix="$home_dir/.pi/agent/npm"
    [[ -d "$prefix/node_modules" ]] || return 0
    win_prefix=$(wslpath -w "$prefix")
    powershell.exe -NoProfile -Command "Set-Location -LiteralPath \$env:TEMP; & npm.cmd install --prefix '$win_prefix'" | tr -d '\r'
}

sync_windows_pi_packages() {
    is_wsl || return 0
    have_cmd powershell.exe || return 0
    have_cmd wslpath || return 0

    local home_dir prefix win_home
    home_dir=$(windows_home_dir) || return 0
    prefix="$home_dir/.pi/agent"
    [[ -d "$prefix/npm/node_modules" || -d "$prefix/git" ]] || return 0
    win_home=$(wslpath -w "$home_dir")
    powershell.exe -NoProfile -Command "Set-Location -LiteralPath '$win_home'; if (Get-Command pi.cmd -ErrorAction SilentlyContinue) { & pi.cmd update --extensions } elseif (Get-Command pi -ErrorAction SilentlyContinue) { & pi update --extensions }" | tr -d '\r'
}

validate_agents_layout() {
    local nested="$DOTFILES_AGENTS_DIR/skills/skills"

    [[ ! -e "$nested" ]] || die "invalid agents layout: $nested exists; skills must live directly under $DOTFILES_AGENTS_DIR/skills"
}

sync_linux_agents() {
    validate_agents_layout
    replace_with_symlink "$DOTFILES_AGENTS_DIR" "$AGENTS_DIR"

    local relpath
    for relpath in "${SKILL_LINKS[@]}"; do
        replace_with_symlink "$AGENTS_DIR/skills" "$HOME/$relpath"
    done
}

sync_linux_config_dirs() {
    local relpath src
    for relpath in "${CONFIG_DIRS[@]}"; do
        src="$DOTFILES_DIR/$relpath"
        [[ -d "$src" ]] || continue
        replace_with_symlink "$src" "$HOME/$relpath"
    done
}

sync_linux_configs() {
    local relpath src
    for relpath in "${CONFIG_LINKS[@]}"; do
        src="$DOTFILES_DIR/$relpath"
        [[ -e "$src" ]] || continue
        replace_config_with_symlink "$src" "$HOME/$relpath"
    done

    sync_linux_config_dirs
}

windows_home_dir() {
    if [[ -n "${WINDOWS_AGENTS_DIR:-}" ]]; then
        dirname "$WINDOWS_AGENTS_DIR"
        return 0
    fi

    if have_cmd powershell.exe && have_cmd wslpath; then
        local win_home
        win_home=$(powershell.exe -NoProfile -Command '[Environment]::GetFolderPath("UserProfile")' 2>/dev/null | tr -d '\r' | tail -n 1)
        [[ -n "$win_home" ]] && wslpath -u "$win_home" && return 0
    fi

    if [[ -d /mnt/c/Users ]]; then
        local dir name
        for dir in /mnt/c/Users/*; do
            [[ -d "$dir" ]] || continue
            name="$(basename "$dir")"
            case "${name,,}" in
                default | defaultuser0 | public | all\ users | desktop.ini) continue ;;
            esac
            printf '%s\n' "$dir"
            return 0
        done
    fi

    return 1
}

windows_agents_dir() {
    if [[ -n "${WINDOWS_AGENTS_DIR:-}" ]]; then
        printf '%s\n' "$WINDOWS_AGENTS_DIR"
        return 0
    fi

    local home_dir
    home_dir=$(windows_home_dir) || return 1
    printf '%s\n' "$home_dir/.agents"
}

sync_windows_agents() {
    is_wsl || return 0
    validate_agents_layout

    local dst parent
    dst=$(windows_agents_dir) || return 0
    parent="$(dirname "$dst")"
    [[ -d "$parent" ]] || return 0

    sync_directory "$DOTFILES_AGENTS_DIR" "$dst"
}

sync_windows_configs() {
    is_wsl || return 0

    local home_dir relpath src
    home_dir=$(windows_home_dir) || return 0
    [[ -d "$home_dir" ]] || return 0

    for relpath in "${CONFIG_LINKS[@]}"; do
        src="$DOTFILES_DIR/$relpath"
        [[ -e "$src" ]] || continue
        sync_config_file "$src" "$home_dir/$relpath"
    done

    for relpath in "${CONFIG_DIRS[@]}"; do
        src="$DOTFILES_DIR/$relpath"
        [[ -d "$src" ]] || continue
        sync_directory "$src" "$home_dir/$relpath"
    done
}

is_plesk_host() {
    have_cmd plesk || return 1
    [[ -d "$PLESK_VHOSTS_DIR" ]]
}

query_plesk_vhosts() {
    plesk db -N -B -e "
        SELECT d.name, s.login, s.home
        FROM domains d
        JOIN hosting h ON d.id = h.dom_id
        JOIN sys_users s ON h.sys_user_id = s.id
        WHERE d.htype = 'vrt_hst'
    " 2>/dev/null || true
}

resolve_path() {
    readlink -f "$1" 2>/dev/null || printf '%s\n' "$1"
}

detect_plesk_claude_group() {
    if [[ -n "$PLESK_CLAUDE_GROUP" ]]; then
        getent group "$PLESK_CLAUDE_GROUP" >/dev/null 2>&1 && {
            printf '%s\n' "$PLESK_CLAUDE_GROUP"
            return 0
        }
        return 1
    fi

    local g
    for g in codex psacln; do
        if getent group "$g" >/dev/null 2>&1; then
            printf '%s\n' "$g"
            return 0
        fi
    done
    return 1
}

active_claude_version_src() {
    local bin
    bin=$(command -v claude 2>/dev/null) || return 1
    bin=$(readlink -f "$bin" 2>/dev/null) || return 1
    [[ -x "$bin" && -f "$bin" ]] || return 1
    printf '%s\n' "$bin"
}

setup_plesk_claude_store() {
    local group store versions src ver wrapper
    group=$(detect_plesk_claude_group) || {
        echo "-> plesk claude: no shared group (set PLESK_CLAUDE_GROUP, or create codex/psacln); skipping shared binary" >&2
        return 1
    }

    store="$PLESK_CLAUDE_DIR"
    versions="$store/versions"
    mkdir -p "$versions"

    if [[ -z "$(find "$versions" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
        src=$(active_claude_version_src) || {
            echo "-> plesk claude: no source claude binary to seed $versions" >&2
            return 1
        }
        ver=$(basename "$src")
        cp -a "$src" "$versions/$ver.tmp.$$"
        mv -f "$versions/$ver.tmp.$$" "$versions/$ver"
        echo "-> plesk claude: seeded $versions/$ver"
    fi

    chgrp -R "$group" "$store" 2>/dev/null || true
    chmod -R g+rX "$store" 2>/dev/null || true
    find "$store" -type d -exec chmod g+ws {} + 2>/dev/null || true

    wrapper="$PLESK_CLAUDE_BIN"
    ensure_parent "$wrapper"
    cat >"$wrapper" <<EOF
#!/bin/sh
umask 002
store="$versions"
bin=""
if [ -d "\$store" ]; then
	for v in \$(ls "\$store" 2>/dev/null | sort -V); do
		[ -x "\$store/\$v" ] && bin="\$store/\$v"
	done
fi
if [ -z "\$bin" ]; then
	echo "claude: no installed version found in \$store" >&2
	exit 127
fi
exec "\$bin" "\$@"
EOF
    chmod 0755 "$wrapper"
    echo "-> plesk claude: store $store (group $group), launcher $wrapper"
    return 0
}

setup_plesk_graphify() {
    local venv="$PLESK_GRAPHIFY_DIR" bin="$PLESK_GRAPHIFY_BIN"

    if [[ ! -x "$venv/bin/graphify" ]]; then
        have_cmd python3 || {
            echo "-> plesk graphify: python3 missing; skipping" >&2
            return 1
        }
        if ! python3 -m venv "$venv" 2>/dev/null; then
            echo "-> plesk graphify: venv creation failed (need python3-venv); skipping" >&2
            return 1
        fi
        "$venv/bin/pip" install --quiet --upgrade pip >/dev/null 2>&1 || true
        if ! "$venv/bin/pip" install --quiet graphifyy >/dev/null 2>&1; then
            echo "-> plesk graphify: pip install graphifyy failed; skipping" >&2
            return 1
        fi
        chmod -R a+rX "$venv" 2>/dev/null || true
    fi

    [[ -x "$venv/bin/graphify" ]] || return 1
    ln -sfn "$venv/bin/graphify" "$bin"
    echo "-> plesk graphify: $bin -> $venv/bin/graphify"
    return 0
}

ensure_user_in_group() {
    local user="$1" group="$2"
    id -nG "$user" 2>/dev/null | tr ' ' '\n' | grep -qx "$group" && return 0
    if usermod -aG "$group" "$user" 2>/dev/null; then
        echo "-> plesk claude: added $user to $group"
    fi
}

link_user_claude() {
    local home_dir="$1" user="$2"
    local store="$PLESK_CLAUDE_DIR" share="$home_dir/.local/share/claude" userbin="$home_dir/.local/bin/claude"

    mkdir -p "$home_dir/.local/share" "$home_dir/.local/bin"

    if [[ -L "$share" ]]; then
        [[ "$(readlink "$share")" == "$store" ]] || {
            rm -f "$share"
            ln -s "$store" "$share"
        }
    elif [[ -e "$share" ]]; then
        echo "-> plesk claude: $share is a private install; leaving it untouched" >&2
    else
        ln -s "$store" "$share"
    fi

    if [[ ! -e "$userbin" && ! -L "$userbin" ]]; then
        ln -s "$PLESK_CLAUDE_BIN" "$userbin"
    fi

    chown -h "$user:" "$share" "$userbin" 2>/dev/null || true
}

sync_plesk_vhost_links() {
    local rows
    rows=$(query_plesk_vhosts)
    [[ -n "$rows" ]] || return 0

    local shared_dotfiles_dir shared_agents_dir
    shared_dotfiles_dir=$(resolve_path "$DOTFILES_DIR")
    shared_agents_dir=$(resolve_path "$DOTFILES_AGENTS_DIR")

    local claude_group=""
    claude_group=$(detect_plesk_claude_group) || true

    local -A seen=()
    local domain plesk_user home_dir ok skip
    ok=0
    skip=0
    while IFS=$'\t' read -r domain plesk_user home_dir; do
        [[ -z "$domain" || -z "$plesk_user" || -z "$home_dir" ]] && continue
        [[ -n "${seen[$home_dir]:-}" ]] && continue
        seen[$home_dir]=1

        if ! id "$plesk_user" >/dev/null 2>&1 || [[ ! -d "$home_dir" ]]; then
            skip=$((skip + 1))
            continue
        fi

        mkdir -p "$home_dir/.claude" "$home_dir/.codex"
        replace_path_with_symlink "$shared_agents_dir" "$home_dir/.agents"
        replace_with_symlink "$home_dir/.agents/skills" "$home_dir/.claude/skills"
        replace_with_symlink "$home_dir/.agents/skills" "$home_dir/.codex/skills"

        local relpath src
        for relpath in "${PLESK_CONFIG_LINKS[@]}"; do
            src="$shared_dotfiles_dir/$relpath"
            [[ -e "$src" ]] || continue
            replace_config_with_symlink "$src" "$home_dir/$relpath"
        done

        for relpath in "${PLESK_COPY_CONFIGS[@]}"; do
            src="$shared_dotfiles_dir/$relpath"
            [[ -e "$src" ]] || continue
            ensure_user_config_copy "$src" "$home_dir/$relpath" "$plesk_user"
        done

        for relpath in "${PLESK_DIR_LINKS[@]}"; do
            src="$shared_dotfiles_dir/$relpath"
            [[ -d "$src" ]] || continue
            replace_path_with_symlink "$src" "$home_dir/$relpath"
        done

        if [[ -n "$claude_group" ]]; then
            ensure_user_in_group "$plesk_user" "$claude_group"
            link_user_claude "$home_dir" "$plesk_user"
        fi

        chown "$plesk_user:" "$home_dir/.claude" "$home_dir/.codex" 2>/dev/null || true
        chown -h "$plesk_user:" \
            "$home_dir/.agents" \
            "$home_dir/.claude/settings.json" \
            "$home_dir/.claude/skills" \
            "$home_dir/.codex/skills" \
            "$home_dir/.config/opencode" \
            "$home_dir/.pi/agent/settings.json" \
            "$home_dir/.pi/agent/prompts" \
            2>/dev/null || true

        ok=$((ok + 1))
    done <<<"$rows"

    echo "-> plesk ai: $ok vhosts configured, $skip skipped"
}

sync_plesk_ai() {
    is_plesk_host || return 0
    validate_agents_layout
    setup_plesk_claude_store || true
    setup_plesk_graphify || true
    sync_plesk_vhost_links
}

sync_all() {
    [[ -d "$DOTFILES_AGENTS_DIR" ]] || die "missing dotfiles agents directory: $DOTFILES_AGENTS_DIR"
    sync_linux_agents
    sync_linux_configs
    sync_linux_npm_packages
    sync_linux_pi_packages
    sync_windows_agents
    sync_windows_configs
    sync_windows_npm_packages
    sync_windows_pi_packages
    sync_plesk_ai
    echo "Done. Restart Codex, Claude, OpenCode, and Pi to pick up changes."
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [command]

Commands:
  sync              Sync agents and config links (default)
  config            Sync config links only
  agents            Sync ~/.agents and CLI skill links only
  skills            Sync skills and Pi prompts, including Plesk vhost links when present
  plesk             Sync skills and Pi prompts to Plesk vhosts only
  windows           Sync .agents, Pi prompts, configs, and Pi npm packages to Windows from WSL only

Options:
  -h, --help        Show this help

Environment:
  DOTFILES_DIR      Dotfiles checkout (default: \$HOME/dotfiles)
  AGENTS_DIR        Linux agents path (default: \$HOME/.agents)
  WINDOWS_AGENTS_DIR Windows agents path override (default: detected Windows user profile + /.agents)
  PLESK_VHOSTS_DIR Plesk vhosts directory (default: /var/www/vhosts)
EOF
}

main() {
    case "${1:-sync}" in
        -h | --help) usage ;;
        sync) sync_all ;;
        config) sync_linux_configs ;;
        agents)
            sync_linux_agents
            sync_plesk_ai
            ;;
        skills)
            sync_linux_agents
            sync_linux_config_dirs
            sync_plesk_ai
            ;;
        plesk) sync_plesk_ai ;;
        windows)
            sync_windows_agents
            sync_windows_configs
            sync_windows_npm_packages
            sync_windows_pi_packages
            ;;
        *) die "unknown command: $1" ;;
    esac
}

main "$@"
