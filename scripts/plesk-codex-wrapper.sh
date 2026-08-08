#!/bin/bash
set -euo pipefail

wrapper_path="$(readlink -f "$0")"
shared_root="$(cd "$(dirname "$wrapper_path")/.." && pwd)"
real_codex="$shared_root/bin/codex-real"
config_template="${CODEX_CONFIG_TEMPLATE:-/etc/codex/config.toml}"
user_codex_home="${CODEX_HOME:-$HOME/.codex}"

if [[ "${1:-}" == "update" ]]; then
    if [[ $# -ne 1 ]]; then
        echo "Usage: codex update" >&2
        exit 2
    fi
    if [[ $EUID -eq 0 ]]; then
        exec /usr/local/sbin/codex-self-update
    fi
    exec sudo -n /usr/local/sbin/codex-self-update
fi

if [[ ! -x "$real_codex" ]]; then
    echo "Codex runtime not found at $real_codex" >&2
    exit 127
fi

if [[ ! -e "$user_codex_home/config.toml" || -L "$user_codex_home/config.toml" ]]; then
    mkdir -p "$user_codex_home"
    chmod 0700 "$user_codex_home"
    if [[ -f "$config_template" ]]; then
        config_tmp=$(mktemp "$user_codex_home/.config.toml.XXXXXX")
        trap 'rm -f "$config_tmp"' EXIT
        install -m 0600 "$config_template" "$config_tmp"
        mv -f "$config_tmp" "$user_codex_home/config.toml"
        trap - EXIT
    fi
fi
if [[ -f "$user_codex_home/config.toml" ]]; then
    sed -i '\|^[[:space:]]*sqlite_home[[:space:]]*=.*"/opt/codex/state"|d' "$user_codex_home/config.toml"
fi

export CODEX_INSTALL_DIR="$shared_root/bin"
export CODEX_SQLITE_HOME="$user_codex_home"
exec "$real_codex" "$@"
