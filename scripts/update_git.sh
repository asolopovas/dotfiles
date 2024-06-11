#!/bin/bash

# Define constants
COMPOSER_PATH="/usr/local/bin/composer"
PNPM_PATH="/usr/local/bin/pnpm" # Assuming pnpm is installed globally

# Function to process a directory
process_directory() {
    local user=$1
    local dir=$2
    local git_action=$3

    echo "Processing directory: $dir with action: $git_action"

    # Check if the directory exists
    if [ ! -d "$dir" ]; then
        echo "Directory $dir does not exist"
        return 1
    fi

    # Check if the directory is a git repository
    if [ ! -d "$dir/.git" ]; then
        echo "Directory $dir is not a git repository"
        return 1
    fi

    # Execute git action

    if [ "$GIT_ACTION" == "reset_to_main" ]; then
        sudo -u "$user" bash -c "cd $dir && git checkout main && git pull origin main"
    fi

    # Execute installation commands
    sudo -u "$user" fish -c "cd $dir && $COMPOSER_PATH install --working-dir='$dir'"
    sudo -u "$user" fish -c "cd $dir && /home/$user/.local/share/pnpm/pnpm install"
    sudo -u "$user" fish -c "cd $dir && /home/$user/.local/share/pnpm/pnpm run prod"

    if [ $? -eq 0 ]; then
        echo "Successfully updated $dir"
    else
        echo "Failed to update $dir"
    fi
}

# Function to checkout the latest tag
checkout_latest_tag() {
    git fetch --tags
    latest_tag=$(git describe --tags $(git rev-list --tags --max-count=1) 2>/dev/null || echo "")
    if [ -z "$latest_tag" ]; then
        echo "No tags found"
        exit 1
    else
        echo "Latest tag is $latest_tag"
        git checkout "$latest_tag" && git pull origin "$latest_tag"
    fi
}

# Function to checkout a specific tag
checkout_specific_tag() {
    local tag=$1
    git fetch --tags && git checkout "$tag" && git pull origin "$tag"
}

# Check if the required parameter is provided
if [ -z "$1" ]; then
    echo "No option specified. Usage: ./update_git.sh --main <user:dir1> <user:dir2> ... | --latest <user:dir1> <user:dir2> ... | --tag <tag> <user:dir1> <user:dir2> ..."
    exit 1
fi

# Determine the action based on the first parameter
ACTION=$1
shift

case $ACTION in
    --main)
        GIT_ACTION="reset_to_main"
        ;;
    --latest)
        GIT_ACTION="checkout_latest_tag"
        ;;
    --tag)
        if [ -z "$1" ]; then
            echo "No tag specified. Usage: ./update_git.sh --tag <tag> <user:dir1> <user:dir2> ..."
            exit 1
        fi
        TAG=$1
        GIT_ACTION="checkout_specific_tag $TAG"
        shift
        ;;
    *)
        echo "Invalid option. Usage: ./update_git.sh --main <user:dir1> <user:dir2> ... | --latest <user:dir1> <user:dir2> ... | --tag <tag> <user:dir1> <user:dir2> ..."
        exit 1
        ;;
esac

# Process each directory
for item in "$@"; do
    IFS=':' read -r user dir <<< "$item"
    if [ -z "$user" ] || [ -z "$dir" ]; then
        echo "Invalid format. Usage: ./update_git.sh --main <user:dir1> <user:dir2> ... | --latest <user:dir1> <user:dir2> ... | --tag <tag> <user:dir1> <user:dir2> ..."
        exit 1
    fi
    process_directory "$user" "$dir" "$GIT_ACTION"
done

echo "All directories updated successfully"
