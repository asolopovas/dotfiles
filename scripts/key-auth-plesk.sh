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
public_key="$(< "$public_key_file")"
public_key="$(echo -n "$public_key" | sed -e 's/^[[:space:]]*//; s/[[:space:]]*$//')"

# Base64-encode into a single line
public_key_b64="$(
  echo -n "$public_key" \
    | base64 \
    | tr -d '\n'
)"

echo "🔄 Connecting to root-new to update authorized_keys for Plesk users..."

# Pass the single-line base64 string to remote
ssh root-new bash -s -- "$force" "$public_key_b64" << 'EOF'
force="$1"
public_key_b64="$2"

# Decode the base64-encoded key
public_key="$(echo "$public_key_b64" | base64 -d)"

# Fetch domain & user pairs in raw tab-separated format (no headers or ASCII table)
plesk_users="$(plesk db -N -B -e "SELECT name, login
                                  FROM domains
                                  JOIN hosting ON domains.id=hosting.dom_id
                                  JOIN sys_users ON hosting.sys_user_id=sys_users.id")"

# Loop through domain / user lines
while IFS=$'\t' read -r domain plesk_user; do

  # If either field is empty, skip
  if [[ -z "$domain" || -z "$plesk_user" ]]; then
    echo "⚠️  Skipping: Invalid domain: $domain or user: $plesk_user."
    continue
  fi

  # Confirm the user actually exists on the system
  if id "$plesk_user" &>/dev/null; then

    user_home="/var/www/vhosts/$domain"
    if [ ! -d "$user_home" ]; then
      echo "⚠️  Skipping $plesk_user ($domain): Home directory $user_home does not exist."
      continue
    fi

    ssh_dir="$user_home/.ssh"
    authorized_keys="$ssh_dir/authorized_keys"

    # Create .ssh if needed
    if [ ! -d "$ssh_dir" ]; then
      echo "📂 Creating .ssh directory for user: $plesk_user ($domain)"
      mkdir -p "$ssh_dir"
      chown "$plesk_user":"$plesk_user" "$ssh_dir"
    fi

    # Overwrite or append the key
    if [ "$force" -eq 1 ]; then
      echo "$public_key" > "$authorized_keys"
      echo "✅ Overwritten authorized_keys for user: $plesk_user ($domain)"
    else
      echo "$public_key" >> "$authorized_keys"
      echo "✅ Appended public key for user: $plesk_user ($domain)"
    fi

    chmod 600 "$authorized_keys"
    chown "$plesk_user":"$plesk_user" "$authorized_keys"

  else
    echo "⚠️  Skipping $plesk_user ($domain): Not a valid system user."
  fi

done <<< "$plesk_users"

EOF

echo "✅ Finished updating authorized_keys for Plesk users!"
