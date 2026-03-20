#!/bin/bash

set -e

target="$HOME/.claude"

if [ "$1" == "--force" ]; then
  for dir in ide statsig shell-snapshots todos projects; do
    rm -rf "$target/$dir"
    mkdir -p "$target/$dir"
  done
fi

npm install -g @anthropic-ai/claude-code

mkdir -p "$target"

cat > "$target/settings.json" <<'EOF'
{
  "includeCoAuthoredBy": false,
  "includeGitInstructions": false
}
EOF

echo "Claude Code installation complete!"
