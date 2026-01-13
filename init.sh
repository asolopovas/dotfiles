#!/bin/bash

export CONFIG_DIR="$HOME/.config"
export DOTFILES_URL="https://github.com/asolopovas/dotfiles.git"
export DOTFILES_DIR="$HOME/dotfiles"
export OS=$(awk -F= '/^ID=/ {gsub(/"/, "", $2); print tolower($2)}' /etc/os-release)
export SCRIPTS_DIR="$DOTFILES_DIR/scripts"

# Arguments
declare -A features=(
    [BUN]=${BUN:-true}
    [DENO]=${DENO:-true}
    [FDFIND]=${FDFIND:-true}
    [FISH]=${FISH:-true}
    [FZF]=${FZF:-true}
    [NODE]=${NODE:-true}
    [NODE_VERSION]=${NODE_VERSION:-22.16.0}
    [UNATTENDED]=${UNATTENDED:-true}
    [OHMYFISH]=${OHMYFISH:-true}
    [NVIM]=${NVIM:-true}
    [CHANGE_SHELL]=${CHANGE_SHELL:-false}
    [CARGO]=${CARGO:-false}
    [FORCE]=${FORCE:-false}
    [OHMYBASH]=${OHMYBASH:-false}
    [OHMYZSH]=${OHMYZSH:-false}
    [SYSTEM]=${SYSTEM:-false}
    [TYPE]=${TYPE:-https}
    [ZSH]=${ZSH:-false}
)

if command -v sudo &>/dev/null && [[ $EUID -ne 0 ]]; then
    SUDO="sudo"
else
    SUDO=""
fi

if ! command -v unzip &> /dev/null; then
    sudo apt update
    sudo apt install -y unzip
fi

cmd_exist() {
    command -v $1 >/dev/null 2>&1
}

mkdir -p $HOME/.tmp $HOME/.config $HOME/.local/bin


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

cleanup() {
    rm -rf "$HOME/.config/nvim"
    rm -rf "$HOME/.config/fish"
    rm -rf "$HOME/.config/tmux"
    rm -rf "$HOME/.volta"
    rm -rf "$HOME/.bun"
    rm -rf "$HOME/.npm"
    rm -rf "$HOME/.deno"
    rm -rf "$HOME/.cache"
    rm -rf "$HOME/.cursor-server"
    rm -rf "$HOME/.local/nvim"
    rm -rf "$HOME/.local/share/nvim"
    rm -rf "$HOME/.local/share/omf"
    rm -rf "$HOME/.local/share/zsh"
    rm -rf "$HOME/.local/share/fish"
    rm -rf "$HOME/.local/share/deno-wrasmbuild"
    rm -rf "$HOME/.local/share/bash-completion"
    rm -rf "$HOME/.local/share/composer"
    rm -rf "$HOME/.local/state/nvim"
    rm -rf "$HOME/.local/state/chrome-debug"
    rm -f "$HOME/.local/bin/helpers"
}
cleanup

install_essentials() {
    print_color green "INSTALLING ESSENTIALS... \n"

    if [ "${features[TYPE]}" = "ssh" ]; then
        DOTFILES_URL="git@github.com:asolopovas/dotfiles.git"
    fi

    if [ ! -d $DOTFILES_DIR ]; then
        print_color green "DOWNLOADING DOTFILES..."
        git clone $DOTFILES_URL $DOTFILES_DIR >/dev/null
    fi

    ln -sf "$DOTFILES_DIR/config/fish" "$CONFIG_DIR"
    ln -sf "$DOTFILES_DIR/config/tmux" "$CONFIG_DIR"
}

install_essentials
install_composer

load_script() {
    local script_name=$1
    local script_path="$SCRIPTS_DIR/inst-$script_name.sh"
    print_color green "Sourcing $script_path"
    [[ -f $script_path ]] && source $script_path
}

# Serialize and export associative array
export features_string=$(declare -p features)

[[ "$UNATTENDED" = false ]] && source $SCRIPTS_DIR/inst-menu.sh

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
source $SCRIPTS_DIR/cfg-default-dirs.sh

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
    load_script "nvim"

    if ! cmd_exist lua; then
        sudo apt install -y lua5.1 luarocks
    fi

    if cmd_exist nvim; then
        ln -sf "$(which nvim)" "$HOME/.local/bin/vim"
    fi
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
