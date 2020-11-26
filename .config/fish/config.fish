#!/bin/fish

if test -n "$DESKTOP_SESSION"
    set -x (gnome-keyring-daemon --start --components=ssh | string split "=")
end

# fish_vi_key_bindings
fish_hybrid_key_bindings

# Add user scripts
set -U fish_user_paths $HOME/.local/bin                  $fish_user_paths
set -U fish_user_paths $HOME/.local/share/gem/bin        $fish_user_paths
set -U fish_user_paths $HOME/.config/composer/vendor/bin $fish_user_paths
set -U fish_user_paths $HOME/.local/yarn/bin             $fish_user_paths
set -U fish_user_paths $HOME/.yarn/bin                   $fish_user_paths
set -U fish_user_paths $HOME/.config/fzf/bin             $fish_user_paths

# Display full path
set -U fish_prompt_pwd_dir_length 0

# Change selection background
set fish_color_search_match --background=blue

set -x TERMINAL alacritty
set -x EDITOR nvim
