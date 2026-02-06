#!/bin/bash

set -euo pipefail

echo "Connecting to remote server..."

ssh root bash --norc -s <<'EOF'
set -euo pipefail

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
    echo "No Plesk users found!"
    exit 1
fi

total=$(echo "$plesk_users" | wc -l)
current=0
ok=0
fail=0
skip=0

printf "Syncing dotfiles for %d users\n\n" "$total"

while IFS=$'\t' read -r domain plesk_user home_dir; do
    current=$((current + 1))
    [[ -z "$domain" || -z "$plesk_user" || -z "$home_dir" ]] && { skip=$((skip + 1)); continue; }

    label="[$current/$total] $domain ($plesk_user)"

    if ! id "$plesk_user" &>/dev/null; then
        printf "  SKIP  %s -- user does not exist\n" "$label"
        skip=$((skip + 1))
        continue
    fi

    if [[ ! -d "$home_dir" ]]; then
        printf "  SKIP  %s -- home dir missing\n" "$label"
        skip=$((skip + 1))
        continue
    fi

    dotfiles_dir="$home_dir/dotfiles"
    if [[ ! -d "$dotfiles_dir/.git" ]]; then
        printf "  SKIP  %s -- no dotfiles repo\n" "$label"
        skip=$((skip + 1))
        continue
    fi

    if output=$(sudo -u "$plesk_user" bash --norc --noprofile -c "
        git -C \$HOME/dotfiles fetch origin main 2>&1 && \
        git -C \$HOME/dotfiles reset --hard origin/main 2>&1 && \
        git -C \$HOME/dotfiles clean -fd 2>&1
    " 2>&1); then
        commit=$(sudo -u "$plesk_user" bash --norc --noprofile -c \
            "git -C \$HOME/dotfiles log -1 --format='%h %s' 2>/dev/null" 2>/dev/null || echo "unknown")
        printf "  OK    %s -> %s\n" "$label" "$commit"
        ok=$((ok + 1))
    else
        printf "  FAIL  %s\n" "$label"
        printf "        %s\n" "$(echo "$output" | tail -1)"
        fail=$((fail + 1))
    fi
done <<< "$plesk_users"

printf "\nDone: %d ok, %d failed, %d skipped (of %d)\n" "$ok" "$fail" "$skip" "$total"
EOF
