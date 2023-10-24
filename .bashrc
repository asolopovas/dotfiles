export DOTFILES=$HOME/dotfiles
export NVM_DIR="$HOME/.nvm"

source $DOTFILES/globals.sh
source $DOTFILES/env/env-vars.sh
source $DOTFILES/env/oh-my-bash.sh

for file in $DOTFILES/completions/bash/*.sh; do
    source $file
done

if cmd_exist fzf; then
    source $DOTFILES/fzf/fzf-opts.sh
    source $DOTFILES/fzf/completion.bash
    source $DOTFILES/fzf/key-bindings.bash
fi

add_paths_from_file $DOTFILES/.paths

[ -f "$HOME/.config/.aliasrc" ] && source $HOME/.config/.aliasrc
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
[ -f "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"  # This loads nvm
[ -f "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
. "$HOME/.cargo/env"
