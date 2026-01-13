#!/bin/fish

# Env
set fish_greeting
set fish_color_search_match --background=blue
set -U fish_prompt_pwd_dir_length 0
set -x SUDO_ASKPASS $HOME/dotfiles/scripts/sec-askpass.sh
set -x TERMINAL alacritty
set -x EDITOR nvim

fish_default_key_bindings
load_env "$HOME/.env-vars"
source $HOME/dotfiles/config/.aliasrc
for line in (cat $HOME/dotfiles/.paths)
    add2path $line
end


# Volta

# Bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH

if type -q bass
    bass source $HOME/dotfiles/env/env-vars.sh
end

# FZF Settings
set FZFARGS
for pattern in (cat $HOME/dotfiles/fzf/fzf-exclude)
    set FZFARGS $FZFARGS -E \"$pattern\"
end
set -u FZF_CTRL_T_COMMAND "fd -H $FZFARGS"
set -U FZF_ALT_C_COMMAND "fd -H -t d $FZFARGS"

fzf_key_bindings

if [ -d "$HOME/go" ]
    set -x GOPATH $HOME/go
    set -x GOBIN $HOME/go/bin
end

if [ -f "$HOME/.local/share/pnpm" ]
    set -gx PNPM_HOME "$HOME/.local/share/pnpm"
    if not string match -q -- $PNPM_HOME $PATH
        set -gx PATH "$PNPM_HOME" $PATH
    end
end

if [ -f "$HOME/.local/google-cloud-sdk/path.fish.inc" ]
    . "$HOME/.local/google-cloud-sdk/path.fish.inc"
end

if [ -f "$HOME/.local/google-cloud-sdk/path.fish.inc" ]
    set -x LD_LIBRARY_PATH "/home/andrius/.rye/tools/rmodel/lib/python3.12/site-packages/nvidia/cudnn/lib:/home/andrius/.rye/tools/rmodel/lib/python3.12/site-packages/nvidia/cuda_runtime/lib:$LD_LIBRARY_PATH"
end


# opencode
fish_add_path /home/andrius/.opencode/bin

function chrome-debug
    bash /home/andrius/dotfiles/scripts/chrome-debug.sh $argv
end
set -gx VOLTA_HOME "$HOME/.volta"
set -gx PATH "$VOLTA_HOME/bin" $PATH
