#!/bin/bash

for userdir in /home/*; do
    if [ -d "${userdir}/dotfiles" ]; then
        cd "${userdir}/dotfiles"
        if [ -d ".git" ]; then
            git reset --hard
            git pull
        else
            echo "'dotfiles' in ${userdir} is not a git repository."
        fi
        cd - >/dev/null
    else
        echo "No 'dotfiles' directory found in ${userdir}."
    fi
done
