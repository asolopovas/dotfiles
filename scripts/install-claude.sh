#!/bin/bash

set -e

echo "Installing Claude Code globally..."
npm install -g @anthropic-ai/claude-code

mkdir -p "$HOME/.claude"
mkdir -p "$HOME/.config/claude"
ln -sf "$HOME/dotfiles/.config/claude/settings.json" "$HOME/.claude/settings.json"
ln -sf "$HOME/dotfiles/.config/claude/commands" "$HOME/.claude/commands"

echo "Claude Code installation complete!"
