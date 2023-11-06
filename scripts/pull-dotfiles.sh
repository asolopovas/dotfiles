#!/bin/bash

for userdir in /home/*; do
    dotfiles_dir="${userdir}/dotfiles"

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
