#!/bin/bash

# Update symlinks script for dotfiles config directory rename
# Run this script after renaming .config to config

echo "Updating symlinks from dotfiles/.config to dotfiles/config..."

# Claude symlinks
ln -sf "$HOME/dotfiles/config/claude/settings.json" "$HOME/.claude/settings.json"
ln -sf "$HOME/dotfiles/config/claude/commands" "$HOME/.claude/commands"

# Config directory symlinks
ln -sf "$HOME/dotfiles/config/fish" "$HOME/.config/fish"
ln -sf "$HOME/dotfiles/config/nvim" "$HOME/.config/nvim"
ln -sf "$HOME/dotfiles/config/tmux" "$HOME/.config/tmux"
ln -sf "$HOME/dotfiles/config/.aliasrc" "$HOME/.config/.aliasrc"
ln -sf "$HOME/dotfiles/config/.func" "$HOME/.config/.func"

echo "Symlinks updated successfully!"
