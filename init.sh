#!/bin/bash

export CONFIG_DIR="$HOME/.config"
export DOTFILES_URL="https://github.com/asolopovas/dotfiles.git"
export DOTFILES_DIR="$HOME/dotfiles"
export SCRIPTS_DIR="$DOTFILES_DIR/scripts"
export OS=$(awk -F= '/^ID=/ {gsub(/"/, "", $2); print tolower($2)}' /etc/os-release)

# Bootstrap utilities (self-contained for curl install)
cmd_exist() { command -v "$1" >/dev/null 2>&1; }
print_color() {
    local -A colors=(['red']='\033[31m' ['green']='\033[0;32m' ['yellow']='\033[0;33m')
    echo -e "${colors[$1]:-}$2\033[0m"
}

# Feature flags with defaults
declare -A features=(
    [BUN]=${BUN:-true}
    [DENO]=${DENO:-true}
    [FDFIND]=${FDFIND:-true}
    [FISH]=${FISH:-true}
    [FZF]=${FZF:-true}
    [NODE]=${NODE:-true}
    [NODE_VERSION]=${NODE_VERSION:-24.13.0}
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

# Export features for child scripts
for feature_name in "${!features[@]}"; do
    export ${feature_name}=${features[$feature_name]}
done

# Setup sudo wrapper
if command -v sudo &>/dev/null && [[ $EUID -ne 0 ]]; then
    SUDO="sudo"
else
    SUDO=""
fi

# Ensure unzip is available
if ! command -v unzip &>/dev/null; then
    $SUDO apt update
    $SUDO apt install -y unzip
fi

# Create essential directories
mkdir -p "$HOME/.tmp" "$HOME/.config" "$HOME/.local/bin"

pushd "$HOME" >/dev/null

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

if [ "${features[FORCE]}" = true ]; then
    echo -e "\033[0;33mFORCE mode: Cleaning existing installations...\033[0m"
    cleanup
fi

install_essentials() {
    print_color green "INSTALLING ESSENTIALS... \n"

    if [ "${features[TYPE]}" = "ssh" ]; then
        DOTFILES_URL="git@github.com:asolopovas/dotfiles.git"
    fi

    if [ ! -d "$DOTFILES_DIR" ]; then
        print_color green "DOWNLOADING DOTFILES..."
        git clone "$DOTFILES_URL" "$DOTFILES_DIR" >/dev/null
    elif [ -d "$DOTFILES_DIR/.git" ]; then
        print_color green "UPDATING DOTFILES..."
        git -C "$DOTFILES_DIR" fetch origin main 2>/dev/null
        git -C "$DOTFILES_DIR" reset --hard origin/main 2>/dev/null
        git -C "$DOTFILES_DIR" clean -fd 2>/dev/null
    fi
}

load_script() {
    local script_name=$1
    local script_path="$SCRIPTS_DIR/inst-$script_name.sh"
    print_color green "Sourcing $script_path"
    [[ -f $script_path ]] && source $script_path
}

# Skip full bootstrap for non-root users with shared dotfiles
if [ "$(id -u)" -ne 0 ] && [ -d /opt/dotfiles ] && [ -L "$HOME/dotfiles" ]; then
    print_color green "Shared dotfiles detected at /opt/dotfiles — skipping bootstrap"
    popd >/dev/null 2>/dev/null || true
    exit 0
fi

install_essentials

# Plesk root: install or sync shared data, then exit
if [ "$(id -u)" -eq 0 ] && [ -d /etc/psa ]; then
    if [ -d /opt/dotfiles ]; then
        print_color green "Plesk server detected — syncing"
        "$SCRIPTS_DIR/plesk-init.sh" sync
    else
        print_color green "Plesk server detected — full install"
        "$SCRIPTS_DIR/plesk-init.sh" all
    fi
    popd >/dev/null
    exit 0
fi

load_script 'composer'

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
    load_script 'bun'
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
    load_script 'fd'
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
        $SUDO apt install -y lua5.1 luarocks
    fi

    if cmd_exist nvim; then
        ln -sf "$(which nvim)" "$HOME/.local/bin/vim"
    fi
fi


if [ "${features[OHMYFISH]}" = true ]; then
    load_script 'ohmyfish'
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
