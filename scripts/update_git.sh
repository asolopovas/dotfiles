#!/bin/bash

# Ensure tag is passed as an argument
if [ -z "$1" ]; then
    echo "No tag specified. Usage: ./update_git.sh <tag> <user:dir1> <user:dir2> ..."
    exit 1
fi

TAG=$1
shift

# Function to process each directory
process_directory() {
    local user=$1
    local dir=$2

    echo "Processing directory: $dir with user: $user"

    sudo -u "$user" bash -c "
        git config --global --add safe.directory '$dir' &&
        cd '$dir' &&
        git fetch --all &&
        git checkout '$TAG' &&
        git pull origin '$TAG' &&
        composer install &&
        pnpm install &&
        pnpm prod
    "

    if [ $? -eq 0 ]; then
        echo "Successfully updated $dir"
    else
        echo "Failed to update $dir"
    fi
}

# Iterate over the remaining arguments which are user:directory pairs
for item in "$@"; do
    IFS=':' read -r user dir <<< "$item"
    if [ -z "$user" ] || [ -z "$dir" ]; then
        echo "Invalid format. Usage: ./update_git.sh <tag> <user:dir1> <user:dir2> ..."
        exit 1
    fi
    process_directory "$user" "$dir"
done

echo "All directories updated successfully"
