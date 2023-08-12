#!/bin/bash

if [ "$FORCE" = true ]; then
    rm -rf $HOME/.local/share/ohmybash
fi

if [ ! -d "$HOME/.local/share/ohmybash" ]; then
    print_color green "INSTALLING OH-MY-BASH..."
    git clone https://github.com/ohmybash/oh-my-bash.git $HOME/.local/share/ohmybash
fi
