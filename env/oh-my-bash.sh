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

ohmybash_dir="$HOME/.local/share/ohmybash"
theme_dir="$ohmybash_dir/custom/themes/theme"
theme_file="$theme_dir/theme.theme.sh"
src_file="$HOME/dotfiles/env/theme.sh"

if [ ! -d "$theme_dir" ] || [ ! -f "$theme_file" ]; then
    mkdir -p "$theme_dir"
    ln -sf "$src_file" "$theme_file"
fi

if [ ! -f "$ohmybash_dir/oh-my-bash.sh" ]; then
    rm -rf $ohmybash_dir;
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)" --unattended
    rm -rf "$HOME/.bashrc*"
    ln -sf "$HOME/dotfiles/.bashrc" "$HOME/.bashrc"
fi

[ -f "$ohmybash_dir/oh-my-bash.sh" ] && source "$ohmybash_dir/oh-my-bash.sh"
