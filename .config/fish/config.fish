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
set -U FZF_FIND_FILE_COMMAND 'fd -E node_modules -E Steam -E npm -E skype -E vscode -E Code -E chrome -E Cache -E cache -E gem -E fish -E python -E .git -E mozilla -E cargo -E log . $HOME'
set -U FZF_CD_COMMAND 'fd -t d -E node_modules -E Steam -E npm -E skype -E vscode -E Code -E chrome -E Cache -E cache -E gem -E fish -E python -E .git -E mozilla -E cargo -E log . $HOME'

# ----------------------------------
# Env Variables
# ----------------------------------
set -x TERMINAL alacritty
set -x EDITOR nvim

source $HOME/.config/.aliasrc
