#!/bin/bash

set -euo pipefail

echo "🔄 Connecting to root-new to retrieve Plesk users and execute 'conf pull'..."

ssh root bash -s <<'EOF'
set -euo pipefail

echo "🔄 Retrieving all Plesk virtual hosting users..."

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

if [[ -z "$plesk_users" ]]; then
    echo "❌ No Plesk users found!"
    exit 1
fi

echo "✅ Found Plesk users. Executing 'conf pull' for each..."

while IFS=$'\t' read -r domain plesk_user home_dir; do
    [[ -z "$domain" || -z "$plesk_user" || -z "$home_dir" ]] && continue

    if ! id "$plesk_user" &>/dev/null; then
        echo "⚠️ User $plesk_user does not exist. Skipping..."
        continue
    fi

    if [[ ! -d "$home_dir" ]]; then
        echo "⚠️ Home directory $home_dir does not exist for $plesk_user. Skipping..."
        continue
    fi

    sudo -u "$plesk_user" bash -c "
        git -C \$HOME/dotfiles fetch origin main && \
        git -C \$HOME/dotfiles reset --hard origin/main && \
        git -C \$HOME/dotfiles clean -fd
    " || echo "❌ Error resetting dotfiles for $plesk_user ($domain)"

done <<< "$plesk_users"

echo "✅ Finished executing 'conf pull' for all Plesk users!"
EOF
