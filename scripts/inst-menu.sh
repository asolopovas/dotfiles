#!/bin/bash

# Deserialize associative array
eval "declare -A features=${features_string#*=}"

CHOICES=$(
    whiptail --title "Dotfiles" --checklist --separate-output "Choose:" 16 60 9 \
        "SYSTEM" "Install host os settings" OFF \
        "DOTFILES" "Dotfiles   " ON \
        "CARGO" "Rust Package Manager  " OFF \
        "FISH" "Unix shell   " ON \
        "FDFIND" "Unix find replacement   " ON \
        "FZF" "Fuzzy Find   " ON \
        "NVM" "NVM   " ON \
        "NVIM" "Neovim modern Vim   " ON \
        "OHMYFISH" "The Fishshell Framework   " ON \
        "ZSH" "Z-Shell Shell  " OFF \
        "OHMYBASH" "Oh My Bash framework  " OFF \
        "OHMYZSH" "Oh My Zsh framework  " OFF \
        "FORCE" "Force install all modules   " OFF \
        "CHANGE_SHELL" "Change default shell to Fish Shell  " OFF \
        3>&1 1>&2 2>&3
)

if [ -z "$CHOICES" ]; then
    print_color green "No options were selected (user hit Cancel or unselected all options)"
    exit
else
    for CHOICE in $CHOICES; do
        case "$CHOICE" in
        "SYSTEM")
            SYSTEM=true
            features[SYSTEM]=true
            ;;
        "DOTFILES")
            DOTFILES=true
            features[DOTFILES]=true
            ;;
        "CARGO")
            CARGO=true
            features[CARGO]=true
            ;;
        "FISH")
            FISH=true
            features[FISH]=true
            ;;
        "FDFIND")
            FDFIND=true
            features[FDFIND]=true
            ;;
        "FZF")
            FZF=true
            features[FZF]=true
            ;;
        "NVM")
            NVM=true
            features[NVM]=true
            ;;
        "NVIM")
            NVIM=true
            features[NVIM]=true
            ;;
        "ZSH")
            ZSH=true
            features[ZSH]=true
            ;;
        "OHMYFISH")
            OHMYFISH=true
            features[OHMYFISH]=true
            ;;
        "OHMYBASH")
            OHMYBASH=true
            features[OHMYBASH]=true
            ;;
        "OHMYZSH")
            OHMYZSH=true
            features[OHMYZSH]=true
            ;;
        "FORCE")
            FORCE=true
            features[FORCE]=true
            ;;
        "CHANGE_SHELL")
            CHANGE_SHELL=true
            features[CHANGE_SHELL]=true
            ;;
        esac
    done
fi

export features
