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
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
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
export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$PATH"
. "$HOME/.cargo/env"
