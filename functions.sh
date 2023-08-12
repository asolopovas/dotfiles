#!/bin/bash

print_color() {
    NC='\033[0m'

    if [ "$1" = "red" ]; then
        COLOR="\033[31m"
    fi

    if [ "$1" = "green" ]; then
        COLOR="\033[0;32m"
    fi

    printf "${COLOR}$2${NC}\n"
}

cmd_exist() {
    command -v "$1" >/dev/null 2>&1
}

load_env_vars() {
    if [ -f "$1" ]; then
        while IFS='=' read -r key value; do
            # Remove leading and trailing whitespace from key
            key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            # Remove leading and trailing whitespace from value
            value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            if ! [ -n "${!key}" ]; then
                export "$key"="$value"
            fi
        done <"$1"
    fi
}

add_paths_from_file() {
    local file_path="$1"

    while IFS= read -r line; do
        if [[ $line == /* ]]; then
            full_path="$line"
        else
            full_path="$HOME/$line"
        fi

        if [ -d "$full_path" ] && [[ ":$PATH:" != *":$full_path:"* ]]; then
            export PATH="$full_path:$PATH"
        fi
    done <"$file_path"
}

create_dir() {
    if [ ! -d "$1" ]; then
        print_color green "Creating $1 ..."
        mkdir -p "$1"
    fi
}

load_env() {
    # Ensure the script stops if there's any errors
    set -e

    # Path to your env-vars file
    ENV_FILE=$1

    if [ -f "$ENV_FILE" ]; then
        # If the file exists, source it
        echo "Loading environment variables from $ENV_FILE"
        set -a
        source "$ENV_FILE"
        set +a
    else
        echo "Environment file $ENV_FILE does not exist"
    fi
}

cd_up() {
  cd $(printf "%-1.s../" $(seq 1 $1 ));
}
