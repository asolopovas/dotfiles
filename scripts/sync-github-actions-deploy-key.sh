#!/usr/bin/env bash

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
KEY_PATH="${HOME}/.ssh/github-actions-modules-deploy"
KEY_COMMENT='github-actions-modules-deploy'

show_help() {
    cat <<HELP
Usage:
    $SCRIPT_NAME [--regenerate] <ssh_host_alias> [ssh_host_alias...]

Options:
    -r, --regenerate   Regenerate key even if it exists
    -h, --help         Show this help

Examples:
    $SCRIPT_NAME alisiagreen threeoakwood
    $SCRIPT_NAME --regenerate alisiagreen threeoakwood
HELP
    exit 0
}

REGENERATE=0
HOSTS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            ;;
        -r|--regenerate)
            REGENERATE=1
            shift
            ;;
        -*)
            echo "Error: unknown option: $1" >&2
            exit 1
            ;;
        *)
            HOSTS+=("$1")
            shift
            ;;
    esac
done

if [[ ${#HOSTS[@]} -eq 0 ]]; then
    echo "Error: provide at least one SSH host alias from ~/.ssh/config" >&2
    exit 1
fi

if [[ "$REGENERATE" -eq 1 ]]; then
    rm -f "$KEY_PATH" "$KEY_PATH.pub"
fi

if [[ ! -f "$KEY_PATH" || ! -f "$KEY_PATH.pub" ]]; then
    ssh-keygen -t ed25519 -a 100 -N '' -C "$KEY_COMMENT" -f "$KEY_PATH"
fi

PUBLIC_KEY="$(<"$KEY_PATH.pub")"
KEY_B64="$(printf '%s' "$PUBLIC_KEY" | base64 | tr -d '\n')"

for host in "${HOSTS[@]}"; do
    if ! ssh -G "$host" >/dev/null 2>&1; then
        echo "[$host] skipped: host alias not available in SSH config"
        continue
    fi

    if ssh "$host" bash -s -- "$KEY_B64" <<'EOF'
set -euo pipefail
key_b64="$1"
key="$(printf '%s' "$key_b64" | base64 -d)"
ssh_dir="$HOME/.ssh"
auth_file="$ssh_dir/authorized_keys"
mkdir -p "$ssh_dir"
touch "$auth_file"
chmod 700 "$ssh_dir"
chmod 600 "$auth_file"
if grep -qxF "$key" "$auth_file"; then
    exit 10
fi
printf '%s\n' "$key" >> "$auth_file"
EOF
    then
        echo "[$host] key added"
    else
        rc=$?
        if [[ "$rc" -eq 10 ]]; then
            echo "[$host] key already exists"
        else
            echo "[$host] failed"
        fi
    fi
done

echo "Private key: $KEY_PATH"
echo "Public key:  $KEY_PATH.pub"
