#!/bin/fish

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
source $HOME/dotfiles/config/.aliasrc

for line in (cat $HOME/dotfiles/.paths)
    add2path $line
end

if type -q bass;
    bass source $HOME/dotfiles/env/env-vars.sh
end

if type -q bass
    set nvm_path $HOME/.nvm/nvm.sh

    if not test -f $nvm_path
        set nvm_path $HOME/.config/nvm/nvm.sh
    end

    if test -f $nvm_path
        bass source $nvm_path
    end
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

# pnpm
set -gx PNPM_HOME "$HOME/.local/share/pnpm"
if not string match -q -- $PNPM_HOME $PATH
    set -gx PATH "$PNPM_HOME" $PATH
end
# pnpm end

if [ -f "$HOME/.local/google-cloud-sdk/path.fish.inc" ]; . "$HOME/.local/google-cloud-sdk/path.fish.inc"; end

set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH



# rmodel CUDA environment
set -x LD_LIBRARY_PATH "/home/andrius/.rye/tools/rmodel/lib/python3.12/site-packages/nvidia/cudnn/lib:/home/andrius/.rye/tools/rmodel/lib/python3.12/site-packages/nvidia/cuda_runtime/lib:$LD_LIBRARY_PATH"
set -gx VOLTA_HOME "$HOME/.volta"
set -gx PATH "$VOLTA_HOME/bin" $PATH

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
if test -d "/home/andrius/miniconda3" -a -f "/home/andrius/miniconda3/bin/conda"
    eval "/home/andrius/miniconda3/bin/conda" "shell.fish" "hook" 2> /dev/null | source
else
    if test -f "/home/andrius/miniconda3/etc/fish/conf.d/conda.fish"
        source "/home/andrius/miniconda3/etc/fish/conf.d/conda.fish"
    else
        set -x PATH "/home/andrius/miniconda3/bin" $PATH
    end
end
# <<< conda initialize <<<
