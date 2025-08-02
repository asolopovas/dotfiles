#!/bin/bash

set -e

echo "Installing Claude Code globally..."
npm install -g @anthropic-ai/claude-code

mkdir -p "$HOME/.claude"
mkdir -p "$HOME/.config/claude"

# Create symbolic links for all Claude configuration
ln -sf "$HOME/dotfiles/config/claude/settings.json" "$HOME/.claude/settings.json"
ln -sf "$HOME/dotfiles/config/claude/commands" "$HOME/.claude/commands"
ln -sf "$HOME/dotfiles/config/claude/agents" "$HOME/.claude/agents"
ln -sf "$HOME/dotfiles/config/claude/hooks" "$HOME/.claude/hooks"
ln -sf "$HOME/dotfiles/config/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"

echo "Claude Code installation complete!"
echo "Configuration linked from ~/dotfiles/config/claude/"
