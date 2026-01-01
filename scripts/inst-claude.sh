#!/bin/bash

set -e

base="$HOME/dotfiles/config/claude"
target="$HOME/.claude"

if [ "$1" == "--force" ]; then
  for dir in ide statsig shell-snapshots todos projects; do
    rm -rf "$target/$dir"
    mkdir -p "$target/$dir"
  done
fi

npm install -g @anthropic-ai/claude-code

mkdir -p "$target"

items=(settings.json CLAUDE.md commands agents hooks)

for item in "${items[@]}"; do
  rm -f "$target/$item"
  ln -sf "$base/$item" "$target/$item"
done

echo "Claude Code installation complete!"
echo "Configuration linked from $base"
