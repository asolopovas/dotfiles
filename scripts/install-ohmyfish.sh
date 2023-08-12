#!/bin/bash

if [ "$FORCE" = true ]; then
    rm -rf $HOME/.local/share/omf
    rm -rf $HOME/.config/omf
fi
if [ ! -d "$HOME/.local/share/omf" ]; then
    print_color green "INSTALLING OH-MY-FISH..."
    curl -sO https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install
    fish install --noninteractive --path=~/.local/share/omf --config=~/.config/omf
    fish -c "omf install bass"
    rm -rf install
fi
