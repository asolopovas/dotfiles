#!/bin/bash

export CONFIG_DIR="$HOME/.config"
export DOTFILES_URL="https://github.com/asolopovas/dotfiles.git"
export DOTFILES_DIR="$HOME/dotfiles"
export SCRIPTS_DIR="$DOTFILES_DIR/scripts"

cmd_exist() { command -v "$1" >/dev/null 2>&1; }
print_color() {
    local -A colors=(['red']='\033[31m' ['green']='\033[0;32m' ['yellow']='\033[0;33m')
    echo -e "${colors[$1]:-}$2\033[0m"
}

_detect_os() {
    case "$(uname -s)" in
        Darwin) echo "macos" ;;
        Linux)
            if [ -f /etc/os-release ]; then
                awk -F= '/^ID=/ {gsub(/"/, "", $2); print tolower($2)}' /etc/os-release
            else echo "linux"; fi
            ;;
        *) echo "unknown" ;;
    esac
}
_detect_arch() {
    case "$(uname -m)" in
        x86_64 | amd64) echo "x86_64" ;;
        aarch64 | arm64) echo "aarch64" ;;
        *) echo "$(uname -m)" ;;
    esac
}
OS="${OS:-$(_detect_os)}"
ARCH="${ARCH:-$(_detect_arch)}"
export OS ARCH

for arg in "$@"; do
    case "$arg" in
        --force) FORCE=true ;;
        --type=*) TYPE="${arg#--type=}" ;;
        --no-fish) FISH=false ;;
        --no-node) NODE=false ;;
        --no-bun) BUN=false ;;
        --no-deno) DENO=false ;;
        --no-nvim) NVIM=false ;;
    esac
done

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
    [CHANGE_SHELL]=${CHANGE_SHELL:-true}
    [CARGO]=${CARGO:-false}
    [FORCE]=${FORCE:-false}
    [OHMYBASH]=${OHMYBASH:-false}
    [OHMYZSH]=${OHMYZSH:-false}
    [SYSTEM]=${SYSTEM:-false}
    [TYPE]=${TYPE:-https}
    [ZSH]=${ZSH:-false}
)

for feature_name in "${!features[@]}"; do
    export "${feature_name}"="${features[$feature_name]}"
done

if command -v sudo &>/dev/null && [[ $EUID -ne 0 ]]; then
    SUDO="sudo"
else
    SUDO=""
fi

if ! command -v unzip &>/dev/null; then
    case "$OS" in
        ubuntu | debian | linuxmint | pop)
            $SUDO apt update && $SUDO apt install -y unzip
            ;;
        fedora)
            $SUDO dnf install -y unzip
            ;;
        centos)
            $SUDO yum install -y unzip
            ;;
        arch)
            $SUDO pacman -S --noconfirm unzip
            ;;
        macos)
            ;; # unzip ships with macOS
    esac
fi

mkdir -p "$HOME/.tmp" "$HOME/.config" "$HOME/.local/bin"

cd "$HOME" || exit 1

cleanup() {
    local dirs=(
        .config/{nvim,fish,tmux} .volta .bun .npm .deno .cache .cursor-server
        .local/nvim .local/share/{nvim,omf,zsh,fish,deno-wrasmbuild,bash-completion,composer}
        .local/state/{nvim,chrome-debug}
    )
    for d in "${dirs[@]}"; do rm -rf "${HOME:?}/$d"; done
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
    # shellcheck disable=SC1090
    [[ -f $script_path ]] && source "$script_path"
}

if [ "$(id -u)" -ne 0 ] && [ -d /opt/dotfiles ] && [ -L "$HOME/dotfiles" ]; then
    print_color green "Shared dotfiles detected at /opt/dotfiles — skipping bootstrap"
    exit 0
fi

install_essentials

if [ "$(id -u)" -eq 0 ] && [ "$HOME" = "/root" ] && [ -d /etc/psa ]; then
    if [ -d /opt/dotfiles ]; then
        print_color green "Plesk server detected — syncing"
        "$SCRIPTS_DIR/plesk-init.sh" sync
    else
        print_color green "Plesk server detected — full install"
        "$SCRIPTS_DIR/plesk-init.sh" all
    fi
    exit 0
fi

load_script 'composer'

features_string=$(declare -p features)
export features_string

[[ "$UNATTENDED" = false ]] && source "$SCRIPTS_DIR/inst-menu.sh"

printf "%-15s %s\n" "FEATURE" "STATUS"
printf '%.0s-' {1..25}
echo
for feature in "${!features[@]}"; do
    printf "%-15s %s\n" "$feature" "$([[ "${features[$feature]}" = true ]] && echo ENABLED || echo DISABLED)"
done
echo

source "$DOTFILES_DIR/globals.sh"
source "$SCRIPTS_DIR/cfg-default-dirs.sh"

fix_broken_symlinks "$HOME/.config" --recursive
fix_broken_symlinks "$HOME/.local/bin"

FORCE_FLAG="${features[FORCE]}"

ensure_tool() {
    local feature_key=$1 cmd_name=$2 script_name=$3
    [[ "${features[$feature_key]}" = true ]] || return 0
    if [[ "$FORCE_FLAG" != true ]] && cmd_exist "$cmd_name"; then
        print_color green "$cmd_name already installed — skipping (use --force to reinstall)"
        return 0
    fi
    load_script "$script_name"
}

ensure_tool BUN bun bun
ensure_tool CARGO cargo cargo
ensure_tool DENO deno deno
ensure_tool FISH fish fish
ensure_tool FDFIND fd fd
ensure_tool FZF fzf fzf
ensure_tool NODE node node

if [[ "${features[NVIM]}" = true ]]; then
    load_script 'nvim'
    cmd_exist lua || pkg_install lua5.1 luarocks
    cmd_exist nvim && ln -sf "$(which nvim)" "$HOME/.local/bin/vim"
fi

[[ "${features[OHMYFISH]}" = true ]] && load_script 'ohmyfish'

if [[ "$OS" != "macos" ]] && command -v timedatectl &>/dev/null; then
    if ! timedatectl show --property=LocalRTC --value 2>/dev/null | grep -qx yes; then
        print_color green "Setting hardware clock to local time (dual-boot Windows fix)"
        $SUDO timedatectl set-local-rtc 1 --adjust-system-clock
    fi
fi

if [[ "$OS" != "macos" ]] && ! grep -qi microsoft /proc/version 2>/dev/null; then
    cmd_exist numlockx || pkg_install numlockx
    [ -d /etc/lightdm/lightdm.conf.d ] && echo -e "[Seat:*]\ngreeter-setup-script=/usr/bin/numlockx on" | $SUDO tee /etc/lightdm/lightdm.conf.d/90-numlock.conf >/dev/null
    [ -f "$HOME/.xprofile" ] && ! grep -q numlockx "$HOME/.xprofile" && echo '[ -x /usr/bin/numlockx ] && /usr/bin/numlockx on' >> "$HOME/.xprofile"
fi

if [[ "${features[CHANGE_SHELL]}" = true ]]; then
    print_color green "CHANGING SHELL TO FISH"
    if command -v fish &>/dev/null; then
        $SUDO chsh -s "$(which fish)" "$(whoami)"
    else
        print_color red "Fish not installed. Please install fish and run this script again."
    fi
fi
