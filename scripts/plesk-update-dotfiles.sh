#!/bin/bash

set -euo pipefail

echo "Connecting to remote server..."

ssh root bash --norc -s <<'EOF'
set -euo pipefail

# sync root dotfiles first
sync_repo() {
    local dir=$1
    git -C "$dir" fetch origin main 2>&1 && \
    git -C "$dir" reset --hard HEAD 2>&1 && \
    git -C "$dir" checkout -B main origin/main 2>&1 && \
    git -C "$dir" clean -fd 2>&1
}

target_commit="unknown"
root_error=""
if [[ -d /root/dotfiles/.git ]]; then
    if root_output=$(sync_repo /root/dotfiles 2>&1); then
        target_commit=$(git -C /root/dotfiles log -1 --format='%h %s' 2>/dev/null || echo "unknown")
    else
        root_error=$(echo "$root_output" | tail -1)
    fi
else
    root_error="no dotfiles repo at /root/dotfiles"
fi

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
total=$((total + 1))
current=1
ok=0
fail=0
skip=0

# count root sync result
if [[ "$target_commit" != "unknown" ]]; then
    ok=1
else
    fail=1
fi

# first pass: compute max width for user column
max_uw=0
while IFS=$'\t' read -r _ plesk_user _; do
    [[ -z "$plesk_user" ]] && continue
    [[ ${#plesk_user} -gt $max_uw ]] && max_uw=${#plesk_user}
done <<< "$plesk_users"

# counter column width: "[31/31]" = digits*2 + 3
digits=${#total}
cw=$((digits * 2 + 3))

printf "Syncing dotfiles for %d users -> %s\n\n" "$total" "$target_commit"

if [[ "$target_commit" != "unknown" ]]; then
    printf "  OK    %-${cw}s  root\n" "[1/$total]"
else
    printf "  FAIL  %-${cw}s  root\n" "[1/$total]"
    [[ -n "$root_error" ]] && printf "        %-${cw}s  %s\n" "" "$root_error"
fi

while IFS=$'\t' read -r domain plesk_user home_dir; do
    current=$((current + 1))
    [[ -z "$domain" || -z "$plesk_user" || -z "$home_dir" ]] && { skip=$((skip + 1)); continue; }

    counter=$(printf "[%d/%d]" "$current" "$total")

    if ! id "$plesk_user" &>/dev/null; then
        printf "  SKIP  %-${cw}s  %-${max_uw}s  -- user does not exist\n" "$counter" "$plesk_user"
        skip=$((skip + 1))
        continue
    fi

    if [[ ! -d "$home_dir" ]]; then
        printf "  SKIP  %-${cw}s  %-${max_uw}s  -- home dir missing\n" "$counter" "$plesk_user"
        skip=$((skip + 1))
        continue
    fi

    dotfiles_dir="$home_dir/dotfiles"
    if [[ ! -d "$dotfiles_dir/.git" ]]; then
        printf "  SKIP  %-${cw}s  %-${max_uw}s  -- no dotfiles repo\n" "$counter" "$plesk_user"
        skip=$((skip + 1))
        continue
    fi

    if output=$(sudo -u "$plesk_user" bash --norc --noprofile -c "
        $(declare -f sync_repo)
        sync_repo \$HOME/dotfiles
    " 2>&1); then
        printf "  OK    %-${cw}s  %-${max_uw}s\n" "$counter" "$plesk_user"
        ok=$((ok + 1))
    else
        printf "  FAIL  %-${cw}s  %-${max_uw}s\n" "$counter" "$plesk_user"
        printf "        %-${cw}s  %-${max_uw}s  %s\n" "" "" "$(echo "$output" | tail -1)"
        fail=$((fail + 1))
    fi
done <<< "$plesk_users"

printf "\nDone: %d ok, %d failed, %d skipped (of %d)\n" "$ok" "$fail" "$skip" "$total"
EOF
