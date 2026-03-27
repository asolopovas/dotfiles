export LIBGUESTFS_DEBUG=1
export LIBGUESTFS_TRACE=1
export NVM_DIR="$HOME/.nvm"
export DOTFILES="$HOME/dotfiles"

source "$DOTFILES/globals.sh"
source "$DOTFILES/env/env-vars.sh"
source "$DOTFILES/env/include-paths.sh"

if [ "$OHMYBASH" == true ]; then
    source "$DOTFILES/env/oh-my-bash.sh"
fi

for file in "$DOTFILES"/completions/bash/*.sh; do
    [ -f "$file" ] && source "$file"
done

if cmd_exist fzf; then
    source "$DOTFILES/fzf/fzf-opts.bash"
    source "$DOTFILES/fzf/completion.bash"
    source "$DOTFILES/fzf/key-bindings.bash"
fi

add_paths_from_file "$DOTFILES/.paths"

[ -f "$HOME/.config/.aliasrc" ] && source "$HOME/.config/.aliasrc"

# Colors and prompt
export PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
export LS_COLORS='di=1;34:ln=1;36:so=1;35:pi=1;33:ex=1;32:bd=1;33:cd=1;33:su=1;31:sg=1;31:tw=1;34:ow=1;34'
export GREP_COLORS='mt=1;31'
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Language toolchains
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
[ -f "$HOME/.deno/env" ] && source "$HOME/.deno/env"
[ -f "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
[ -f "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
*":$PNPM_HOME:"*) ;;
*) export PATH="$PNPM_HOME:$PATH" ;;
esac

# SDKMAN (must be at end)
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# volta
export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$PATH"

# rmodel CUDA environment
export LD_LIBRARY_PATH="$HOME/.rye/tools/rmodel/lib/python3.12/site-packages/nvidia/cudnn/lib:$HOME/.rye/tools/rmodel/lib/python3.12/site-packages/nvidia/cuda_runtime/lib:${LD_LIBRARY_PATH:-}"
[ -f ~/.rmodel_cuda_setup.sh ] && source ~/.rmodel_cuda_setup.sh

# Extra completions
[ -f "$HOME/dotfiles/completions/bash/clean-data" ] && source "$HOME/dotfiles/completions/bash/clean-data"
[ -f "$HOME/.bash_completion.d/wp-seo" ] && source "$HOME/.bash_completion.d/wp-seo"
[ -f "$HOME/.bash_completions/rmodel.sh" ] && source "$HOME/.bash_completions/rmodel.sh"

export PATH="$HOME/.pixi/bin:$HOME/.local/bin:$PATH"
