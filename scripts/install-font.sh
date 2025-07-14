#!/bin/bash

install_font() {
    font=$1
    mkdir -p ~/.local/share/fonts/$font
    for ext in zip tar.xz; do
        url="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/$font.$ext"
        file="/tmp/$font.$ext"
        if curl -L --progress-bar "$url" -o "$file"; then
            case $ext in
                zip) unzip "$file" -d ~/.local/share/fonts/$font ;;
                tar.xz) tar -xf "$file" -C ~/.local/share/fonts/$font ;;
            esac
            rm "$file"
            break  # Exit the loop once a file has been successfully downloaded and extracted
        fi
    done
}

# If no arguments are provided, set the default fonts
if [ "$#" -eq 0 ]; then
    set -- FiraMono JetBrainsMono
fi

for font in "$@"; do
    install_font "$font"
done

# Update the font cache
fc-cache -fv
