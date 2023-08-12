OS=$(awk '/^ID=/' /etc/os-release | sed -e 's/ID=//' -e 's/"//g' | tr '[:upper:]' '[:lower:]')
DOTFILES=$HOME/dotfiles
export NVM_DIR="$HOME/.nvm"

source $DOTFILES/env/env-vars.sh
source $DOTFILES/functions.sh
source $DOTFILES/env/oh-my-bash.sh

if cmd_exist fzf; then
    source $DOTFILES/fzf/fzf-opts.sh
    source $DOTFILES/fzf/completion.bash
    source $DOTFILES/fzf/key-bindings.bash
fi

[ -f "$HOME/.config/.aliasrc" ] && source $HOME/.config/.aliasrc
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

add_paths_from_file $DOTFILES/.paths

[ -f "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -f "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
