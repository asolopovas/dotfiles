#!/bin/bash

DISABLE_AUTO_UPDATE="true"
OSH_THEME="theme"

completions=(
    git
    composer
    ssh
)

aliases=(
    general
)

plugins=(
    git
    bashmarks
)

theme_dir="$HOME/.local/share/ohmybash/custom/themes/theme"
theme_file="$theme_dir/theme.theme.sh"
src_file="$HOME/dotfiles/env/theme.sh"

[ ! -d "$theme_dir" ] || [ ! -f "$theme_file" ]; \
mkdir -p "$theme_dir" >/dev/null; \
ln -sf "$src_file" "$theme_file" >/dev/null

[ -f "$OSH/oh-my-bash.sh" ] && source "$OSH/oh-my-bash.sh"
