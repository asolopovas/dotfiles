#!/bin/bash

if [ -z "$1" ]; then
    echo "No tag specified. Usage: ./update_git.sh <tag> <user:dir1> <user:dir2> ..."
    exit 1
fi

TAG=$1
shift

COMPOSER_PATH="/usr/local/bin/composer"

process_directory() {
    local user=$1
    local dir=$2
    local pnpm_path="/home/$user/.local/share/pnpm/pnpm"

    echo "Processing directory: $dir with user: $user"

    sudo -H -u "$user" fish -c "
        cd '$dir' &&
        git config --add safe.directory '$dir' &&
        git fetch --all &&
        git checkout '$TAG' &&
        git pull origin '$TAG' &&
        $COMPOSER_PATH install --working-dir='$dir' &&
        $pnpm_path install &&
        $pnpm_path run prod
    "

    if [ $? -eq 0 ]; then
        echo "Successfully updated $dir"
    else
        echo "Failed to update $dir"
    fi
}

for item in "$@"; do
    IFS=':' read -r user dir <<< "$item"
    if [ -z "$user" ] || [ -z "$dir" ]; then
        echo "Invalid format. Usage: ./update_git.sh <tag> <user:dir1> <user:dir2> ..."
        exit 1
    fi
    process_directory "$user" "$dir"
done

echo "All directories updated successfully"
