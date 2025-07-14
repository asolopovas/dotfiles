#!/bin/bash

process_directory() {
    local user=$1
    local dir=$2
    local git_action=$3
    local tag=$4

    echo "Processing directory: $dir with action: $git_action"

    if [ ! -d "$dir" ]; then
        echo "Directory $dir does not exist"
        return 1
    fi

    if [ ! -d "$dir/.git" ]; then
        echo "Directory $dir is not a git repository"
        return 1
    fi

    if [ "$GIT_ACTION" == "checkout_specific_tag" ]; then
        sudo -u "$user" bash -c "cd $dir && git fetch --tags && git checkout $tag && git pull origin $tag"
    fi

    if [ "$GIT_ACTION" == "checkout_latest_tag" ]; then
        git fetch --tags
        latest_tag=$(git describe --tags $(git rev-list --tags --max-count=1) 2>/dev/null || echo "")

        if [ -z "$latest_tag" ]; then
            echo "No tags found"
            exit 1
        else
            echo "Latest tag is $latest_tag"
            git checkout "$latest_tag" && git pull origin "$latest_tag"
        fi
    fi

    if [ "$GIT_ACTION" == "reset_to_main" ]; then
        sudo -u "$user" bash -c "cd $dir && git checkout main && git pull origin main"
    fi

    COMPOSER_PATH="/usr/local/bin/composer"
    PHP_CLI="/usr/local/bin/php"

    sudo -u "$user" bash -c "cd $dir && $PHP_CLI $COMPOSER_PATH install --working-dir='$dir'"
    sudo -u "$user" fish -c "cd $dir && /home/$user/.local/share/pnpm/pnpm install"
    sudo -u "$user" fish -c "cd $dir && /home/$user/.local/share/pnpm/pnpm run prod"

    if [ $? -eq 0 ]; then
        echo "Successfully updated $dir"
    else
        echo "Failed to update $dir"
    fi
}



if [ -z "$1" ]; then
    echo "No option specified. Usage: ./update_git.sh --main <user:dir1> <user:dir2> ... | --latest <user:dir1> <user:dir2> ... | --tag <tag> <user:dir1> <user:dir2> ..."
    exit 1
fi

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
        GIT_ACTION="checkout_specific_tag"
        if [ -z "$1" ]; then
            echo "No tag specified. Usage: ./update_git.sh --tag <tag> <user:dir1> <user:dir2> ..."
            exit 1
        fi
        TAG=$1
        shift
        ;;
    *)
        echo "Invalid option. Usage: ./update_git.sh --main <user:dir1> <user:dir2> ... | --latest <user:dir1> <user:dir2> ... | --tag <tag> <user:dir1> <user:dir2> ..."
        exit 1
        ;;
esac

for item in "$@"; do
    IFS=':' read -r user dir <<< "$item"
    if [ -z "$user" ] || [ -z "$dir" ]; then
        echo "Invalid format. Usage: ./update_git.sh --main <user:dir1> <user:dir2> ... | --latest <user:dir1> <user:dir2> ... | --tag <tag> <user:dir1> <user:dir2> ..."
        exit 1
    fi
    process_directory "$user" "$dir" "$GIT_ACTION" $TAG
done

echo "All directories updated successfully"
