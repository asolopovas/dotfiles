#!/bin/bash

# Ensure tag is passed as an argument
if [ -z "$1" ]; then
    echo "No tag specified. Usage: ./update_git.sh <tag> <dir1> <dir2> ..."
    exit 1
fi

TAG=$1
shift

# Iterate over the remaining arguments which are directories
for dir in "$@"; do
    echo "Processing directory: $dir"

    cd $dir || { echo "Failed to change directory to $dir"; exit 1; }
    git fetch --all || { echo "Failed to fetch from remote"; exit 1; }
    git checkout $TAG || { echo "Failed to checkout tag $TAG"; exit 1; }
    git pull origin $TAG || { echo "Failed to pull from origin"; exit 1; }
    composer install || { echo "Composer install failed"; exit 1; }
    pnpm install || { echo "PNPM install failed"; exit 1; }
    pnpm prod || { echo "PNPM prod failed"; exit 1; }

    echo "Successfully updated $dir"
done

echo "All directories updated successfully"
