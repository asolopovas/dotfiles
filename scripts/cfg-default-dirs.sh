#!/bin/bash

source $HOME/dotfiles/globals.sh

# Skip for non-root users with shared dotfiles (managed by plesk-init.sh)
if [ "$(id -u)" -ne 0 ] && [ -d /opt/dotfiles ] && [ -L "$HOME/dotfiles" ]; then
    print_color green "Shared dotfiles detected — symlinks managed by plesk-init.sh"
    return 0 2>/dev/null || exit 0
fi

print_color green "Creating Defaults Directories ..."

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
    ".Xresources"
    ".gitignore"
    ".config/.func"
    ".config/.aliasrc"
    ".config/btop/btop.conf"
    ".config/fish"
    ".config/tmux"
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
        ".config/inputrc"
        ".config/mimeapps.list"
        ".config/picom.conf"
        ".config/wall.jpg"
        ".config/Xresources"
        ".profile"
        ".xprofile"
        ".xinitrc"
        ".ideavimrc"
        ".gtkrc-2.0"
        ".globignore"
        ".gitconfig"
    )
fi

if [ "$NVIM" = true ] && ! { [ "$(id -u)" -ne 0 ] && [ -d "/opt/nvim-data/nvim/lazy" ]; }; then
    CONFDIRS+=(".config/nvim")
fi

if [ "$ZSH" = true ]; then
    CONFDIRS+=(".config/.zshrc")
fi

print_color green "Creating Symlinks ..."
for src in "${CONFDIRS[@]}"; do
    srcPath="$DOTFILES_DIR/$src"
    destPath="$HOME/$src"

    if [ -L "$destPath" ]; then
        link_target="$(readlink "$destPath" 2>/dev/null || true)"
        if [ "$link_target" = "$srcPath" ]; then
            continue
        fi
    fi

    if [ -e "$destPath" ] || [ -L "$destPath" ]; then
        rm -rf "$destPath"
    fi

    # Ensure parent directory exists before creating symlink
    mkdir -p "$(dirname "$destPath")"
    ln -sf "$srcPath" "$destPath"
done

ln -sf $DOTFILES_DIR/helpers $HOME/.local/bin
