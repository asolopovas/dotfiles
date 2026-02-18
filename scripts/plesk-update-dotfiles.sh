#!/bin/bash

set -euo pipefail

echo "Connecting to remote server..."

ssh root bash --norc -s <<'EOF'
set -euo pipefail

sync_repo() {
    local dir=$1
    git -C "$dir" fetch origin main 2>&1 && \
    git -C "$dir" reset --hard HEAD 2>&1 && \
    git -C "$dir" clean -fd 2>&1 && \
    git -C "$dir" checkout -B main origin/main 2>&1
}

# Sync root dotfiles from git
target_commit="unknown"
if [[ -d /root/dotfiles/.git ]]; then
    if sync_repo /root/dotfiles &>/dev/null; then
        target_commit=$(git -C /root/dotfiles log -1 --format='%h %s' 2>/dev/null || echo "unknown")
        printf "  OK    root -> %s\n" "$target_commit"
    else
        printf "  FAIL  root -- git sync failed\n"
        exit 1
    fi
else
    printf "  FAIL  root -- no dotfiles repo at /root/dotfiles\n"
    exit 1
fi

# Sync to shared location if plesk-install-dotfiles.sh has been run
if [[ -d /opt/dotfiles ]]; then
    rsync -a --delete --exclude='.git' --exclude='tests/' /root/dotfiles/ /opt/dotfiles/
    chown -R root:root /opt/dotfiles
    chmod -R u+rwX,go+rX,go-w /opt/dotfiles
    printf "  OK    /opt/dotfiles synced\n"

    # Also update shared nvim config if it exists
    if [[ -d /opt/nvim-config/nvim ]]; then
        rsync -a --delete /root/dotfiles/.config/nvim/ /opt/nvim-config/nvim/
        chown -R root:root /opt/nvim-config
        chmod -R u+rwX,go+rX,go-w /opt/nvim-config
        printf "  OK    /opt/nvim-config synced\n"
    fi

    # Also update shared opencode config if it exists
    if [[ -d /opt/opencode-config ]] && [[ -d /root/.config/opencode ]]; then
        rsync -a --delete \
            --exclude='antigravity-accounts.json' \
            --exclude='antigravity-accounts.json.*.tmp' \
            --exclude='antigravity-signature-cache.json' \
            --exclude='antigravity-logs/' \
            --exclude='logs/' \
            /root/.config/opencode/ /opt/opencode-config/
        chown -R root:root /opt/opencode-config
        chmod -R u+rwX,go+rX,go-w /opt/opencode-config
        printf "  OK    /opt/opencode-config synced\n"
    fi
else
    printf "  SKIP  /opt/dotfiles not set up (run plesk-install-dotfiles.sh first)\n"
fi

printf "\nDone: %s\n" "$target_commit"
EOF
