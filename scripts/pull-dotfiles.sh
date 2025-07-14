#!/bin/bash

source $HOME/dotfiles/globals.sh

for userdir in /home/*; do
    dotfiles_dir="${userdir}/dotfiles"

    print_color green "---------------------------------------"
    print_color green "Pulling dotfiles in $dotfiles_dir"
    print_color green "---------------------------------------"

    if [ -d "$dotfiles_dir" ]; then
        owner=$(stat -c '%U' "$dotfiles_dir")
        if [ -d "$dotfiles_dir/.git" ]; then
            sudo -u "$owner" git -C "$dotfiles_dir" reset --hard
            sudo -u "$owner" git -C "$dotfiles_dir" pull
        else
            echo "'dotfiles' in ${userdir} is not a git repository."
        fi
    else
        echo "No 'dotfiles' directory found in ${userdir}."
    fi
done
