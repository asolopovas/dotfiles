#!/bin/bash
set -euo pipefail
source "$HOME/dotfiles/globals.sh"

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
TARGET="$HOME/.claude"

if [ "${1:-}" = "--force" ]; then
    print_color yellow "FORCE: clearing claude state dirs"
    for dir in ide statsig shell-snapshots todos projects; do
        rm -rf "${TARGET:?}/$dir"
        mkdir -p "$TARGET/$dir"
    done
fi

if [ "${FORCE:-false}" != true ] && cmd_exist claude; then
    print_color green "claude already installed — skipping installer"
else
    print_color green "Installing Claude Code..."
    curl -fsSL https://claude.ai/install.sh | bash
fi

SYNC_TARGETS=claude "$DOTFILES_DIR/scripts/sync-ai.sh" config
print_color green "Claude Code installation complete. Run sync-ai.sh for skills/MCP."
