#!/bin/bash
# execute-conf-pull.sh
#
# This script runs "conf pull" for all Plesk virtual hosting users on a remote Plesk server.
#
# Usage:
#   ./execute-conf-pull.sh
#

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
    id "$plesk_user" &>/dev/null || { echo "⚠️  Skipping $plesk_user: User does not exist."; continue; }
    [ -d "$home_dir" ] || { echo "⚠️  Skipping $plesk_user: Home directory not found."; continue; }

    echo "🚀 Running 'conf pull' for $plesk_user ($domain)..."

    sudo -u "$plesk_user" -- bash -c 'conf pull' && \
        echo "✅ Successfully executed 'conf pull' for $plesk_user ($domain)" || \
        echo "❌ Failed to execute 'conf pull' for $plesk_user ($domain)"

done <<< "$plesk_users"

echo "✅ Finished executing 'conf pull' for all Plesk users!"
EOF
