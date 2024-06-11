#!/bin/bash

# Ensure tag is passed as an argument
if [ -z "$1" ]; then
    echo "No tag specified. Usage: ./update_git.sh <tag> <user:dir1> <user:dir2> ..."
    exit 1
fi

TAG=$1
shift

# Iterate over the remaining arguments which are user:directory pairs
for item in "$@"; do
    IFS=':' read -r user dir <<< "$item"
    if [ -z "$user" ] || [ -z "$dir" ]; then
        echo "Invalid format. Usage: ./update_git.sh <tag> <user:dir1> <user:dir2> ..."
        exit 1
    fi
    echo "Processing directory: $dir with user: $user"

    sudo -u $user bash -c "
        git config --global --add safe.directory $dir
        cd $dir || { echo 'Failed to change directory to $dir'; exit 1; }
        git fetch --all || { echo 'Failed to fetch from remote'; exit 1; }
        git checkout $TAG || { echo 'Failed to checkout tag $TAG'; exit 1; }
        git pull origin $TAG || { echo 'Failed to pull from origin'; exit 1; }
        if ! composer install; then
            echo 'Composer install failed'; exit 1
        fi
        if ! pnpm install; then
            echo 'PNPM install failed'; exit 1
        fi
        if ! pnpm prod; then
            echo 'PNPM prod failed'; exit 1
        fi
    "

    if [ $? -eq 0 ]; then
        echo "Successfully updated $dir"
    else
        echo "Failed to update $dir"
    fi
done

echo "All directories updated successfully"
