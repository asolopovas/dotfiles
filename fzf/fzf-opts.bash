FZFARGS=""
while read -r pattern; do
    FZFARGS+="-E \"$pattern\" "
done <"$HOME/dotfiles/fzf/fzf-exclude"

# FZF Settings
export FZF_DEFAULT_OPTS="--layout=reverse --height 50%"
export FZF_CTRL_T_COMMAND="fd -t f -H $FZFARGS ."
export FZF_ALT_C_COMMAND="fd -t d -H $FZFARGS ."
