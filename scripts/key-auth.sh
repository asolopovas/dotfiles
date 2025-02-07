#!/usr/bin/env bash
# add-ssh-key.sh
#
# Usage:
#   ./add-ssh-key.sh [-f] <public_key_file>
#
# Options:
#   -f   Overwrite existing authorized_keys instead of appending.

set -euo pipefail

usage() {
  echo "Usage: $0 [-f] <public_key_file>"
  exit 1
}

# Default: append mode
force=0

# Check arguments
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

# Read and trim the public key from the file
public_key="$(< "$public_key_file")"
public_key="$(echo -n "$public_key" | sed -e 's/^[[:space:]]*//; s/[[:space:]]*$//')"

# Base64-encode the key to avoid whitespace splitting
public_key_b64="$(echo -n "$public_key" | base64)"

echo "🔑 Connecting to root to update authorized_keys for real cPanel users..."

# Pass the base64-encoded key to the remote script
ssh root bash -s -- "$force" "$public_key_b64" << 'EOF'
force="$1"
public_key_b64="$2"

# Decode the key
public_key="$(echo "$public_key_b64" | base64 -d)"

# 1) Get the list of cPanel accounts
cpanel_users=$(ls -1 /var/cpanel/users 2>/dev/null || true)

# 2) For each user, verify it's real, then update authorized_keys
for user in $cpanel_users; do
  if id "$user" &>/dev/null; then
    user_home="/home/$user"
    if [ -d "$user_home" ]; then
      ssh_dir="$user_home/.ssh"
      authorized_keys="$ssh_dir/authorized_keys"

      # Create .ssh if needed
      if [ ! -d "$ssh_dir" ]; then
        echo "ℹ️  Creating .ssh directory for user: $user"
        mkdir -p "$ssh_dir"
        chmod 700 "$ssh_dir"
        chown "$user":"$user" "$ssh_dir"
      fi

      # Overwrite (-f) or append
      if [ "$force" -eq 1 ]; then
        echo "$public_key" > "$authorized_keys"
        echo "✅ Overwritten authorized_keys for user: $user"
      else
        echo "$public_key" >> "$authorized_keys"
        echo "✅ Appended public key for user: $user"
      fi

      chmod 600 "$authorized_keys"
      chown "$user":"$user" "$authorized_keys"
    else
      echo "⚠️  Skipping $user: /home/$user does not exist."
    fi
  else
    echo "⚠️  Skipping $user: not a valid user in /etc/passwd."
  fi
done
EOF

echo "🎉 Finished updating authorized_keys for cPanel users!"
