#!/bin/fish


if test -n "$DESKTOP_SESSION"
    set -x (gnome-keyring-daemon --start --components=ssh | string split "=")
end

# Fish
set fish_greeting
fish_hybrid_key_bindings
# Change selection background
set fish_color_search_match --background=blue
# Display full path
set -U fish_prompt_pwd_dir_length 0

# Add user scripts
set PATH $HOME/.local/bin                  $PATH
set PATH $HOME/.local/share/gem/bin        $PATH
set PATH $HOME/.config/composer/vendor/bin $PATH
set PATH $HOME/.local/yarn/bin             $PATH
set PATH $HOME/.yarn/bin                   $PATH
set PATH $HOME/.config/fzf/bin             $PATH

set -x TERMINAL alacritty
set -x EDITOR nvim
