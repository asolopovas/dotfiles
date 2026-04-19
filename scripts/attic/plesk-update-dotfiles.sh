#!/bin/bash
set -euo pipefail

# Pull latest dotfiles on remote server and sync shared data.
# Designed to run locally — SSHes into root on the remote server.

echo "Connecting to remote server..."

ssh root bash --norc -s <<'EOF'
set -euo pipefail

# Pull latest main
if [[ ! -d /root/dotfiles/.git ]]; then
    printf "FAIL  no dotfiles repo at /root/dotfiles\n"
    exit 1
fi

git -C /root/dotfiles fetch origin main 2>/dev/null
git -C /root/dotfiles reset --hard HEAD 2>/dev/null
git -C /root/dotfiles clean -fd 2>/dev/null
git -C /root/dotfiles checkout -B main origin/main 2>/dev/null

commit=$(git -C /root/dotfiles log -1 --format='%h %s' 2>/dev/null)
printf "OK    root -> %s\n" "$commit"

# Sync shared data (if plesk-init.sh has been run before)
if [[ -d /opt/dotfiles ]]; then
    /root/dotfiles/scripts/plesk-init.sh sync
else
    printf "SKIP  /opt/dotfiles not set up (run plesk-init.sh first)\n"
fi

printf "\nDone: %s\n" "$commit"
EOF
