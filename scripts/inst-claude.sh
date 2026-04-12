#!/bin/bash

set -e

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
target="$HOME/.claude"

if [ "$1" == "--force" ]; then
  for dir in ide statsig shell-snapshots todos projects; do
    rm -rf "$target/$dir"
    mkdir -p "$target/$dir"
  done
fi

npm install -g @anthropic-ai/claude-code

# Config is synced from dotfiles via sync-ai.sh
SYNC_TARGETS=claude "$DOTFILES_DIR/scripts/sync-ai.sh" config

echo "Claude Code installation complete!"
echo "Run 'sync-ai.sh' to install skills and MCP servers."
