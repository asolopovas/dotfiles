#!/bin/fish

if set -q DESKTOP_SESSION
    set -x (gnome-keyring-daemon --start --components=pkcs11,secrets,ssh,gpg | string split "=")
end

# ----------------------------------
# Fish
# ----------------------------------
fish_default_key_bindings
set fish_greeting
set fish_color_search_match --background=blue
set -U fish_prompt_pwd_dir_length 0

# ----------------------------------
# Add user scripts
# ----------------------------------
set PATH $HOME/.local/bin                  $PATH
set PATH $HOME/.local/share/gem/bin        $PATH
set PATH $HOME/.config/composer/vendor/bin $PATH
set PATH $HOME/.local/yarn/bin             $PATH
set PATH $HOME/.yarn/bin                   $PATH
set PATH $HOME/.config/fzf/bin             $PATH

# ----------------------------------
# Env Variables
# ----------------------------------
set -x TERMINAL alacritty
set -x EDITOR nvim
