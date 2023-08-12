#!/bin/bash

OS=$(awk -F= '/^ID=/ {gsub(/"/, "", $2); print tolower($2)}' /etc/os-release)

export DOTFILES_DIR="$HOME/dotfiles"
export SCRIPTS_DIR="$DOTFILES_DIR/scripts"
export PI=$HOME/.tmp/p

mkdir -p $HOME/.tmp

# Arguments
declare -A features=(
    [TYPE]=${TYPE:-https}
    [CARGO]=${CARGO:-false}
    [FDFIND]=${FDFIND:-false}
    [FISH]=${FISH:-false}
    [FORCE]=${FORCE:-false}
    [FZF]=${FZF:-false}
    [NODE]=${NODE:-false}
    [NODE_VERSION]=${NODE_VERSION:-18.16.1}
    [NVIM]=${NVIM:-false}
    [OHMYBASH]=${OHMYBASH:-false}
    [OHMYFISH]=${OHMYFISH:-false}
    [OHMYZSH]=${OHMYZSH:-false}
    [UNATTENDED]=${UNATTENDED:-false}
    [SYSTEM]=${SYSTEM:-false}
    [ZSH]=${ZSH:-false}
    [CHANGE_SHELL]=${CHANGE_SHELL:-false}
)

for feature_name in "${!features[@]}"; do
    export ${feature_name}=${features[$feature_name]}
done

pushd $HOME >/dev/null

cmd_exist() {
    command -v "$1" >/dev/null
}

print_color() {
    declare -A colors=(
        ['red']='\033[31m'
        ['green']='\033[0;32m'
    )
    echo -e "${colors[$1]}$2\033[0m"
}

setup_locale() {
    LOCALE=${1:-en_US.UTF-8}
    sudo sed -i "s/# $LOCALE UTF-8/$LOCALE UTF-8/" /etc/locale.gen
    sudo locale-gen $LOCALE
    sudo update-locale LC_ALL=$LOCALE LANG=$LOCALE
    source ~/.bashrc
    echo "$LOCALE setup complete!"
}

install_essentials() {
    print_color green "INSTALLING ESSENTIALS... \n"
    if [ "$OS" = "ubuntu"  ]; then
        setup_locale
    fi
    if ! cmd_exist python && ! cmd_exist python3 || ! cmd_exist git || [ ! -f $PI ]; then
        curl -fsSL https://raw.githubusercontent.com/asolopovas/dotfiles/master/helpers/system/p >$PI
        chmod +x $PI
        $PI i python3 git >/dev/null

        if [ "$OS" = "alpine" ]; then
            sudo ln -sf $(which python3) /usr/bin/python
            $PI i newt >/dev/null
        fi
    fi

    URL="https://github.com/asolopovas/dotfiles.git"
    if [ "${features[TYPE]}" = "ssh" ]; then
        URL="git@github.com:asolopovas/dotfiles.git"
    fi

    if [ ! -d $DOTFILES_DIR ]; then
        print_color green "DOWNLOADING DOTFILES..."
        git clone $URL $DOTFILES_DIR >/dev/null
    fi
}

install_essentials

source_script() {
    local script_name=$1
    local script_path="$SCRIPTS_DIR/install-$script_name.sh"
    print_color green "Sourcing $script_path"
    [[ -f $script_path ]] && source $script_path
}


# Serialize and export associative array
export features_string=$(declare -p features)

[[ "$UNATTENDED" = false ]] && source $SCRIPTS_DIR/install-menu.sh

echo -e "FEATURE\t\tSTATUS"
separator="------------\t--------"
echo -e $separator
for feature in "${!features[@]}"; do
    if [ "${features[$feature]}" = true ]; then
        status="ENABLED"
    else
        status="DISABLED"
    fi
    printf "%-15s %s\n" "$feature" "$status"
done
echo -e "$separator\n"

source $DOTFILES_DIR/functions.sh
source $SCRIPTS_DIR/default-dirs.sh

if [ "${features[FISH]}" = true ]; then
    source_script 'fish'
fi

if [ "${features[CARGO]}" = true ]; then
    curl https://sh.rustup.rs -sSf | sh
fi

if [ "${features[FDFIND]}" = true ] && ! cmd_exist fd; then
    source_script "fd"
fi

if [ "${features[FZF]}" = true ]; then
    source_script "fzf"
fi

if [ "${features[NODE]}" = true ]; then
    source_script "node"
fi

if [ "${features[NVIM]}" = true ]; then
    source_script "nvim"
fi

if [ "${features[ZSH]}" = true ]; then
    print_color green "INSTALLING ZSH..."
    $PI i zsh >/dev/null
fi

if [ "${features[OHMYFISH]}" = true ]; then
    source_script "ohmyfish"
fi

if [ "${features[OHMYZSH]}" = true ]; then
    source_script "ohmyzsh"
fi

if [ "${features[OHMYBASH]}" = true ]; then
    source_script "ohmybash"
fi

if [ "${features[CHANGE_SHELL]}" = true ] && [ "$UNATTENDED" = false ]; then
    print_color green "CHANGING SHELL TO FISH"
    chsh -s $(which fish)
fi

popd >/dev/null
