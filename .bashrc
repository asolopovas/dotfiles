export LIBGUESTFS_DEBUG=1
export LIBGUESTFS_TRACE=1
export NVM_DIR="$HOME/.nvm"
export DOTFILES="$HOME/dotfiles"

source $DOTFILES/globals.sh
source $DOTFILES/env/env-vars.sh
source $DOTFILES/env/include-paths.sh

if [ "$OHMYBASH" == true ]; then
    source $DOTFILES/env/oh-my-bash.sh
fi

for file in $DOTFILES/completions/bash/*.sh; do
    source $file
done

if cmd_exist fzf; then
    source $DOTFILES/fzf/fzf-opts.bash
    source $DOTFILES/fzf/completion.bash
    source $DOTFILES/fzf/key-bindings.bash
fi

add_paths_from_file $DOTFILES/.paths

[ -f "$HOME/.config/.aliasrc" ] && source $HOME/.config/.aliasrc

# Colors and prompt
export PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
export LS_COLORS='di=1;34:ln=1;36:so=1;35:pi=1;33:ex=1;32:bd=1;33:cd=1;33:su=1;31:sg=1;31:tw=1;34:ow=1;34'
export GREP_COLORS='mt=1;31'
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
[ -f "$HOME/.deno/env" ] && source "$HOME/.deno/env"
[ -f "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"                   # This loads nvm
[ -f "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion" # This loads nvm bash_completion

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
*":$PNPM_HOME:"*) ;;
*) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

[ -f ~/.rmodel_cuda_setup.sh ] && source ~/.rmodel_cuda_setup.sh  # rmodel CUDA setup
export PATH="$HOME/.local/bin:$PATH"
[ -f "$HOME/dotfiles/completions/bash/clean-data" ] && source "$HOME/dotfiles/completions/bash/clean-data"

# wp-seo completion
[ -f "/home/andrius/.bash_completion.d/wp-seo" ] && source /home/andrius/.bash_completion.d/wp-seo
export PATH="/home/andrius/.pixi/bin:$PATH"
export LD_LIBRARY_PATH="/home/andrius/.rye/tools/rmodel/lib/python3.12/site-packages/nvidia/cudnn/lib:/home/andrius/.rye/tools/rmodel/lib/python3.12/site-packages/nvidia/cuda_runtime/lib:$LD_LIBRARY_PATH"

# rmodel CUDA environment
export LD_LIBRARY_PATH="/home/andrius/.rye/tools/rmodel/lib/python3.12/site-packages/nvidia/cudnn/lib:/home/andrius/.rye/tools/rmodel/lib/python3.12/site-packages/nvidia/cuda_runtime/lib:$LD_LIBRARY_PATH"

[ -f '/home/andrius/.bash_completions/rmodel.sh' ] && source '/home/andrius/.bash_completions/rmodel.sh'

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$PATH"

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
if [ -d "/home/andrius/miniconda3" ] && [ -f "/home/andrius/miniconda3/bin/conda" ]; then
    __conda_setup="$('/home/andrius/miniconda3/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
    if [ $? -eq 0 ]; then
        eval "$__conda_setup"
    else
        if [ -f "/home/andrius/miniconda3/etc/profile.d/conda.sh" ]; then
            . "/home/andrius/miniconda3/etc/profile.d/conda.sh"
        else
            export PATH="/home/andrius/miniconda3/bin:$PATH"
        fi
    fi
    unset __conda_setup
fi
# <<< conda initialize <<<

