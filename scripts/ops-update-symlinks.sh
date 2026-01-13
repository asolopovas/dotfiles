#!/bin/sh

set -eu

DOTFILES_DIR=${DOTFILES_DIR:-"$HOME/dotfiles"}
XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-"$HOME/.config"}

# Avoid writing inside the repo if user set a risky value
if [ "$XDG_CONFIG_HOME" = "$DOTFILES_DIR/.config" ]; then
  echo "Refusing to use XDG_CONFIG_HOME=$XDG_CONFIG_HOME (points into repo)" >&2
  exit 1
fi

mkdir -p "$XDG_CONFIG_HOME"

# src|dst mappings; only replace existing destination symlinks
while IFS='|' read -r src dst; do
  [ -n "$src" ] || continue
  dstdir=$(dirname "$dst")
  [ -d "$dstdir" ] || mkdir -p "$dstdir"
  [ -L "$dst" ] && rm -f "$dst"
  ln -s "$src" "$dst"
done <<EOF
$DOTFILES_DIR/.config/claude/settings.json|$HOME/.claude/settings.json
$DOTFILES_DIR/.config/claude/commands|$HOME/.claude/commands
$DOTFILES_DIR/.config/fish|$XDG_CONFIG_HOME/fish
$DOTFILES_DIR/.config/nvim|$XDG_CONFIG_HOME/nvim
$DOTFILES_DIR/.config/tmux|$XDG_CONFIG_HOME/tmux
$DOTFILES_DIR/.config/.aliasrc|$XDG_CONFIG_HOME/.aliasrc
$DOTFILES_DIR/.config/.func|$XDG_CONFIG_HOME/.func
EOF
