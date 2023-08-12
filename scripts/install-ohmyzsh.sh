#!/bin/bash

if [ "$FORCE" = true ]; then
    rm -rf $HOME/.oh-my-zsh
fi

if [ ! -d "$HOME/.local/share/ohmyzsh" ]; then
    print_color green "INSTALLING OH-MY-ZSH..."
    ZSH="$HOME/.local/share/ohmyzsh" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    ln -sf $HOME/dotfiles/.config/zsh $HOME/.config/zsh
    ln -sf $HOME/dotfiles/.config/zsh/.zshrc $HOME/.zshrc
fi
