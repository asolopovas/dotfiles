#!/bin/bash

# Ensure tag is passed as an argument
if [ -z "$1" ]; then
    echo "No tag specified. Usage: ./update_git.sh <tag> <dir1:user1> <dir2:user2> ..."
    exit 1
fi

TAG=$1
shift

# Iterate over the remaining arguments which are directories and their respective users
for item in "$@"; do
    IFS=':' read -r dir user <<< "$item"
    if [ -z "$user" ]; then
        user=$(whoami)
    fi
    echo "Processing directory: $dir with user: $user"

    sudo -u $user bash -c "
        git config --global --add safe.directory $dir
        cd $dir || { echo 'Failed to change directory to $dir'; exit 1; }
        git fetch --all || { echo 'Failed to fetch from remote'; exit 1; }
        git checkout $TAG || { echo 'Failed to checkout tag $TAG'; exit 1; }
        git pull origin $TAG || { echo 'Failed to pull from origin'; exit 1; }
        composer install || { echo 'Composer install failed'; exit 1; }
        pnpm install || { echo 'PNPM install failed'; exit 1; }
        pnpm prod || { echo 'PNPM prod failed'; exit 1; }
    "

    if [ $? -eq 0 ]; then
        echo "Successfully updated $dir"
    else
        echo "Failed to update $dir"
    fi
done

echo "All directories updated successfully"
