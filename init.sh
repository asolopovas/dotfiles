#!/bin/bash

OS=$(awk -F= '/^ID=/ {gsub(/"/, "", $2); print tolower($2)}' /etc/os-release)

export DOTFILES_DIR="$HOME/dotfiles"
export SCRIPTS_DIR="$DOTFILES_DIR/scripts"

cmd_exist() {
    command -v $1 >/dev/null 2>&1
}

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
    [UNATTENDED]=${UNATTENDED:-true}
    [SYSTEM]=${SYSTEM:-false}
    [ZSH]=${ZSH:-false}
    [CHANGE_SHELL]=${CHANGE_SHELL:-false}
)

for feature_name in "${!features[@]}"; do
    export ${feature_name}=${features[$feature_name]}
done

pushd $HOME >/dev/null

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

install_composer() {
    COMPOSER_PATH="$HOME/.local/bin/composer"
    if [ ! -f "$COMPOSER_PATH" ]; then
        echo "Installing Composer..."
        mkdir -p "$(dirname "$COMPOSER_PATH")"
        curl -sS https://getcomposer.org/download/latest-stable/composer.phar -o "$COMPOSER_PATH"
        chmod +x "$COMPOSER_PATH"
        echo "Composer installed successfully at $COMPOSER_PATH."
    else
        echo "Composer is already installed at $COMPOSER_PATH."
    fi
}
install_package() {
    print_color green "Installing the following packages for ${OS^}:"
    for pkg in "$@"; do
        print_color blue "  - $pkg"
    done
    case $OS in
    ubuntu | debian | linuxmint)
        sudo apt install -y "$@"
        ;;
    centos)
        sudo yum install -y "$@"
        ;;
    arch)
        sudo pacman -S --noconfirm "$@"
        ;;
    esac
}

install_essentials() {
    print_color green "INSTALLING ESSENTIALS... \n"
    if [ "$OS" = "ubuntu" ]; then
        setup_locale
    fi

    sudo add-apt-repository -y ppa:fish-shell/release-3 >/dev/null 2>&1
    install_package fish python3 git

    if [ "$OS" = "alpine" ]; then
        sudo ln -sf $(which python3) /usr/bin/python
        install_package newt >/dev/null
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
install_composer
curl -fsSL https://bun.sh/install | bash
load_script() {
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

source $DOTFILES_DIR/globals.sh
source $SCRIPTS_DIR/default-dirs.sh

if [ "${features[FISH]}" = true ]; then
    load_script 'fish'
fi

if [ "${features[CARGO]}" = true ]; then
    curl https://sh.rustup.rs -sSf | sh
fi

if [ "${features[FDFIND]}" = true ] && ! cmd_exist fd; then
    load_script "fd"
fi

if [ "${features[FZF]}" = true ]; then
    load_script "fzf"
fi

if [ "${features[NODE]}" = true ]; then
    load_script "node"
fi

if [ "${features[NVIM]}" = true ]; then
    load_script "nvim"
fi

if [ "${features[ZSH]}" = true ]; then
    print_color green "INSTALLING ZSH..."
    install_package zsh >/dev/null
fi

if [ "${features[OHMYFISH]}" = true ]; then
    load_script "ohmyfish"
fi

if [ "${features[OHMYZSH]}" = true ]; then
    load_script "ohmyzsh"
fi

if [ "${features[OHMYBASH]}" = true ]; then
    load_script "ohmybash"
fi

if [ "${features[CHANGE_SHELL]}" = true ] && [ "$UNATTENDED" = false ]; then
    print_color green "CHANGING SHELL TO FISH"
    chsh -s $(which fish)
fi

popd >/dev/null
