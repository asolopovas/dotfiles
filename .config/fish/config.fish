#!/bin/fish

# # Start Gnome Keyring
# if set -q DESKTOP_SESSION
#     set -x (gnome-keyring-daemon --start --components=pkcs11,secrets,ssh,gpg | string split "=")
# end

# Fish
fish_default_key_bindings
set fish_greeting
set fish_color_search_match --background=blue
set -U fish_prompt_pwd_dir_length 0

# Env Variables
set -x SUDO_ASKPASS $HOME/dotfiles/scripts/askpass.sh
set -x TERMINAL alacritty
set -x EDITOR nvim
set -x GOPATH $HOME/go
set -x GOBIN $HOME/go/bin

# Aliases
source $HOME/dotfiles/.config/.aliasrc

for line in (cat $HOME/dotfiles/.paths)
    add2path $line
end

# # Load Environment Variables
# load_env_vars "$HOME/.env-vars"
if type -q bass;
    bass source $HOME/dotfiles/env/env-vars.sh
end


if type -q bass; and test -f $HOME/.nvm/nvm.sh
    bass source $HOME/.nvm/nvm.sh
end

# FZF Settings
set FZFARGS
for pattern in (cat $HOME/dotfiles/fzf/fzf-exclude)
    set FZFARGS $FZFARGS -E \"$pattern\"
end

set -u FZF_CTRL_T_COMMAND "fd -H $FZFARGS"
set -U FZF_ALT_C_COMMAND "fd -H -t d $FZFARGS"

fzf_key_bindings

load_env "$HOME/.env-vars"

#  TMUX
if status is-interactive
    and not set -q TMUX
    and set -q SSH_CONNECTION
    tmux attach-session -t ssh_tmux > /dev/null 2>&1; or tmux new-session -s ssh_tmux
end

# pnpm
set -gx PNPM_HOME "/home/andrius/.local/share/pnpm"
if not string match -q -- $PNPM_HOME $PATH
  set -gx PATH "$PNPM_HOME" $PATH
end
# pnpm end
# The next line updates PATH for the Google Cloud SDK.
if [ -f '/home/andrius/.local/google-cloud-sdk/path.fish.inc' ]; . '/home/andrius/.local/google-cloud-sdk/path.fish.inc'; end
