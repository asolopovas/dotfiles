#!/bin/bash

OS=$(awk -F= '/^ID=/ {gsub(/"/, "", $2); print tolower($2)}' /etc/os-release)

DOTFILES_URL="https://github.com/asolopovas/dotfiles.git"
export DOTFILES_DIR="$HOME/dotfiles"
export SCRIPTS_DIR="$DOTFILES_DIR/scripts"

if command -v sudo &>/dev/null && [[ $EUID -ne 0 ]]; then
    SUDO="sudo"
else
    SUDO=""
fi

cmd_exist() {
    command -v $1 >/dev/null 2>&1
}

mkdir -p $HOME/.tmp $HOME/.config $HOME/.local/bin

# Arguments
declare -A features=(
    [BUN]=${BUN:-true}
    [CARGO]=${CARGO:-false}
    [DENO]=${DENO:-false}
    [FDFIND]=${FDFIND:-true}
    [FISH]=${FISH:-true}
    [FORCE]=${FORCE:-false}
    [FZF]=${FZF:-true}
    [NODE]=${NODE:-false}
    [NODE_VERSION]=${NODE_VERSION:-22.13.1}
    [NVIM]=${NVIM:-true}
    [OHMYBASH]=${OHMYBASH:-false}
    [OHMYFISH]=${OHMYFISH:-true}
    [OHMYZSH]=${OHMYZSH:-false}
    [UNATTENDED]=${UNATTENDED:-true}
    [SYSTEM]=${SYSTEM:-false}
    [TYPE]=${TYPE:-https}
    [ZSH]=${ZSH:-false}
    [CHANGE_SHELL]=${CHANGE_SHELL:-false}
)

for feature_name in "${!features[@]}"; do
    export ${feature_name}=${features[$feature_name]}
done

pushd $HOME
print_color() {
    declare -A colors=(
        ['red']='\033[31m'
        ['green']='\033[0;32m'
    )
    echo -e "${colors[$1]}$2\033[0m"
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
        $SUDO apt install -y "$@"
        ;;
    centos)
        $SUDO yum install -y "$@"
        ;;
    arch)
        $SUDO pacman -S --noconfirm "$@"
        ;;
    esac
}

install_essentials() {
    print_color green "INSTALLING ESSENTIALS... \n"

    if [ "${features[TYPE]}" = "ssh" ]; then
        DOTFILES_URL="git@github.com:asolopovas/dotfiles.git"
    fi

    if [ ! -d $DOTFILES_DIR ]; then
        print_color green "DOWNLOADING DOTFILES..."
        git clone $DOTFILES_URL $DOTFILES_DIR >/dev/null
    fi

    rm -rf "$HOME/.config/fish" >/dev/null
    ln -sf "$DOTFILES_DIR/.config/fish" "$HOME/.config"
    ln -sf "$DOTFILES_DIR/.config/tmux" "$HOME/.config"
}

install_essentials
install_composer
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

if [ "${features[BUN]}" = true ]; then
    curl -fsSL https://bun.sh/install | bash
fi

if [ "${features[CARGO]}" = true ]; then
    curl https://sh.rustup.rs -sSf | sh
fi

if [ "${features[DENO]}" = true ]; then
    load_script 'deno'
fi

if [ "${features[FISH]}" = true ] && ! cmd_exist fish; then
    load_script 'fish'
fi

if [ "${features[FDFIND]}" = true ] && ! cmd_exist fd; then
    VER="10.2.0"
    FILE="fd-v${VER}-x86_64-unknown-linux-gnu"
    print_color green "Installing fd find for ${OS^} from ${DOTFILES_URL}..."
    curl -fssLO https://github.com/sharkdp/fd/releases/download/v$VER/$FILE.tar.gz
    tar -xf $FILE.tar.gz -C . $FILE/fd
    mv $FILE/fd $HOME/.local/bin
    rm -rf $FILE $FILE.tar.gz
fi

if [ "${features[FZF]}" = true ]; then
    load_script "fzf"
fi

if [ "${features[NODE]}" = true ]; then
    load_script "node"
fi

if [ "${features[NVIM]}" = true ]; then
    if ! cmd_exist nvim; then
        load_script "nvim"
    fi

    AUTOLOAD_DIR="$HOME/.local/share/nvim/site/autoload"

    if [ ! -d "$AUTOLOAD_DIR" ] && cmd_exist nvim; then
        print_color green "Installing vim-plug ..."
        curl -sfLo $AUTOLOAD_DIR/plug.vim --create-dirs \
            https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
        bash -c "nvim +silent +PlugInstall +qall"
    fi

    ln -sf $(which nvim) $HOME/.local/bin/vim
fi

if [ "${features[OHMYFISH]}" = true ]; then
    DEST_DIR="$HOME/.local/share/omf"
    if [ ! -d "$DEST_DIR" ]; then
        print_color green "Installing OhMyFish for ${OS^} to $DEST_DIR ..."
        curl -sO https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install
        fish install --noninteractive --path=$DEST_DIR --config=$HOME/.config/omf
        fish -c "omf install bass"
        rm -f install
    fi
fi

if [ "${features[CHANGE_SHELL]}" = true ]; then
    print_color green "CHANGING SHELL TO FISH"

    if command -v fish &>/dev/null; then
        chsh -s $(which fish)
    else
        print_color red "Fish not installed. Please install fish and run this script again."
    fi
fi

popd >/dev/null
