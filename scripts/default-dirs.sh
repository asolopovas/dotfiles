#!/bin/bash

print_color green "CREATING DEFAULT DIRS ..."

source $HOME/dotfiles/functions.sh

DEFAULT_DIRS=(
    "src"
    ".local/bin"
    ".local/share"
    ".local/.config"
    ".cache"
)

create_dir "$HOME/.config"

for DIR in "${DEFAULT_DIRS[@]}"; do
    create_dir "$HOME/$DIR"
done

if cmd_exist zsh; then
    touch $HOME/.cache/.zsh_history
fi

CONFDIRS=(
    ".bashrc"
    ".gitconfig"
    ".gitignore"
    ".config/.func"
    ".config/.aliasrc"
)

if [ "$SYSTEM" = true ]; then
    CONFDIRS+=(
        ".xsessionrc"
        ".config/alacritty"
        ".config/Dharkael"
        ".config/dunst"
        ".config/gtk-2.0"
        ".config/gtk-3.0"
        ".config/pcmanfm"
        ".config/polybar"
        ".config/rofi"
        ".config/tmux"
        ".config/xmonad"
        ".config/inputrc"
        ".config/mimeapps.list"
        ".config/picom.conf"
        ".config/wall.jpg"
        ".config/Xresources"
        ".config/autostart.sh"
        ".profile"
        ".xprofile"
        ".xinitrc"
        ".ideavimrc"
        ".gtkrc-2.0"
        ".globignore"
        ".gitconfig"
    )
fi

if [ "$NVIM" = true ]; then
    CONFDIRS+=(".config/nvim")
fi

if [ "$ZSH" = true ]; then
    CONFDIRS+=(".config/.zshrc")
fi

print_color green "CREATING SYMLINKS ..."
for src in "${CONFDIRS[@]}"; do
    srcPath="$DOTFILES_DIR/$src"
    destPath="$HOME/$src"

    echo "$HOME/$src"
    if [ -d "$destPath" ]; then
        rm -rf $destPath
    fi
    ln -sf $srcPath $destPath
done

echo "$HOME/.local/bin/helpers"
ln -sf $DOTFILES_DIR/helpers $HOME/.local/bin > /dev/null