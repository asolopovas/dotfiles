#!/bin/fish

# Keep non-interactive shells quiet and fast for ssh/scp/rsync automation.
# Interactive-only aliases, prompts, completions, and toolchain startup files
# must not print output or slow down protocol commands such as dsync.
if test -f "$HOME/.env-vars"; and functions -q load_env
    load_env "$HOME/.env-vars"
end

if not status is-interactive
    return
end

set fish_greeting

set -g fish_csi_u 0
set -g fish_prompt_pwd_dir_length 0
set -gx COLORFGBG "15;0"
set -x SUDO_ASKPASS $HOME/dotfiles/scripts/sec-askpass.sh
set -x TERMINAL alacritty
set -x EDITOR nvim

fish_default_key_bindings

if test -f "$HOME/dotfiles/.config/.aliasrc"
    source "$HOME/dotfiles/.config/.aliasrc"
end

if test -f "$HOME/dotfiles/.paths"; and functions -q add2path
    for line in (cat "$HOME/dotfiles/.paths")
        add2path $line
    end
end

set -gx BUN_INSTALL "$HOME/.bun"
fish_add_path $BUN_INSTALL/bin

# node: latest Plesk node on server, Volta locally
set -l plesk_nodes /opt/plesk/node/*/bin
if test (count $plesk_nodes) -gt 0
    set -l plesk_node (printf '%s\n' $plesk_nodes | sort -V | tail -1)
    fish_add_path $plesk_node
else if test -d "$HOME/.volta"
    set -gx VOLTA_HOME "$HOME/.volta"
    fish_add_path "$VOLTA_HOME/bin"
end

if type -q bass
    bass source $HOME/dotfiles/env/env-vars.sh
end

set FZFARGS
for pattern in (cat $HOME/dotfiles/fzf/fzf-exclude)
    set FZFARGS $FZFARGS -E \"$pattern\"
end
set -gx FZF_CTRL_T_COMMAND "fd -H $FZFARGS"
set -gx FZF_ALT_C_COMMAND "fd -H -t d $FZFARGS"

if functions -q fzf_key_bindings
    fzf_key_bindings
end

if [ -d "$HOME/go" ]
    set -x GOPATH $HOME/go
    set -x GOBIN $HOME/go/bin
end

if [ -f "$HOME/.local/google-cloud-sdk/path.fish.inc" ]
    . "$HOME/.local/google-cloud-sdk/path.fish.inc"
end

if [ -f "$HOME/.rmodel_cuda_setup.sh" ]
    set -x LD_LIBRARY_PATH "$HOME/.rye/tools/rmodel/lib/python3.12/site-packages/nvidia/cudnn/lib:$HOME/.rye/tools/rmodel/lib/python3.12/site-packages/nvidia/cuda_runtime/lib:$LD_LIBRARY_PATH"
end

fish_add_path $HOME/.opencode/bin

# The phone is connected to Windows. Use its ADB server from WSL.
alias adb='adb.exe'

function chrome-debug
    bash $HOME/dotfiles/scripts/chrome-debug.sh $argv
end

# pnpm
set -gx PNPM_HOME "/home/andrius/.local/share/pnpm"
if not string match -q -- "$PNPM_HOME/bin" $PATH
    set -gx PATH "$PNPM_HOME/bin" $PATH
end
# pnpm end
