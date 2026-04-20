#!/bin/bash
set -euo pipefail
source "$HOME/dotfiles/globals.sh"

VER="$(gh_latest_release ryanoasis/nerd-fonts --keep-v)"
print_color green "Installing Nerd Fonts ${VER}..."

install_font() {
    local font="$1"
    local dest="$HOME/.local/share/fonts/$font"
    mkdir -p "$dest"
    for ext in zip tar.xz; do
        local url="https://github.com/ryanoasis/nerd-fonts/releases/download/${VER}/${font}.${ext}"
        local file="/tmp/${font}.${ext}"
        if curl -fL --progress-bar "$url" -o "$file"; then
            case $ext in
                zip) unzip -oq "$file" -d "$dest" ;;
                tar.xz) tar -xf "$file" -C "$dest" ;;
            esac
            rm -f "$file"
            return 0
        fi
    done
    return 1
}

[ "$#" -eq 0 ] && set -- FiraMono JetBrainsMono

for font in "$@"; do
    install_font "$font" || print_color red "Failed to install $font"
done

fc-cache -fv >/dev/null
