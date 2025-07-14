#!/usr/bin/env bash
# key-auth-plesk.sh
#
# Usage:
#   ./key-auth-plesk.sh [-f] <public_key_file>
#
# Options:
#   -f   Overwrite existing authorized_keys instead of appending.

set -euo pipefail

usage() {
    echo "Usage: $0 [-f] <public_key_file>"
    exit 1
}

force=0
if [ $# -lt 1 ]; then
    usage
fi

# Detect optional "-f"
if [ "$1" = "-f" ]; then
    force=1
    shift
    if [ $# -lt 1 ]; then
        usage
    fi
fi

public_key_file="$1"

if [ ! -f "$public_key_file" ]; then
    echo "❌ No valid public key file found: $public_key_file"
    exit 1
fi

# Read & trim any leading/trailing whitespace
public_key="$(<"$public_key_file")"
public_key="$(echo -n "$public_key" | sed -e 's/^[[:space:]]*//; s/[[:space:]]*$//')"

# Base64-encode into a single line
public_key_b64="$(
    echo -n "$public_key" |
        base64 |
        tr -d '\n'
)"

echo "🔄 Connecting to root to update authorized_keys for Plesk users..."

ssh root bash -s -- "$force" "$public_key_b64" <<'EOF'
force="$1"
public_key_b64="$2"

# Decode the base64-encoded key
public_key="$(echo "$public_key_b64" | base64 -d)"

# Pull only real (virtual) hosting domains, retrieving domain name, user login, and the actual home dir:
plesk_users="$(
  plesk db -N -B -e "
    SELECT d.name, s.login, s.home
    FROM domains d
    JOIN hosting h ON d.id = h.dom_id
    JOIN sys_users s ON h.sys_user_id = s.id
    WHERE d.htype = 'vrt_hst'
  "
)"

while IFS=$'\t' read -r domain plesk_user home_dir; do
    [[ -z "$domain" || -z "$plesk_user" || -z "$home_dir" ]] && continue
    id "$plesk_user" &>/dev/null || continue
    [ -d "$home_dir" ] || continue

    ssh_dir="$home_dir/.ssh"
    authorized_keys="$ssh_dir/authorized_keys"

    # Create .ssh if needed
    if [ ! -d "$ssh_dir" ]; then
        echo "📂 Creating .ssh directory for user: $plesk_user ($domain)"
        mkdir -p "$ssh_dir"
        chown "$plesk_user":"$plesk_user" "$ssh_dir"
    fi

    if [ "$force" -eq 1 ]; then
        # Overwrite authorized_keys
        echo "$public_key" > "$authorized_keys"
        echo "✅ Overwritten authorized_keys for user: $plesk_user ($domain)"
    else
        # Append only if the key is not already there
        if [ -f "$authorized_keys" ] && grep -qxF "$public_key" "$authorized_keys"; then
            echo "ℹ️  Key already present for user: $plesk_user ($domain). Skipping addition."
        else
            echo "$public_key" >> "$authorized_keys"
            echo "✅ Appended public key for user: $plesk_user ($domain)"
        fi
    fi

    chmod 600 "$authorized_keys"
    chown "$plesk_user":psacln "$authorized_keys"

done <<< "$plesk_users"

EOF

echo "✅ Finished updating authorized_keys for Plesk users!"
