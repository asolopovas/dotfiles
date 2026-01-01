#!/bin/bash

# Configure Gnome Terminal to match Alacritty colors and settings
# Based on colors from /home/andrius/dotfiles/config/alacritty/alacritty.toml

PROFILE_ID="b1dcc9dd-5262-4d8d-a863-c897e6d979b9"

echo "Configuring Gnome Terminal to match Alacritty..."

# Create the profile if it doesn't exist
CURRENT_PROFILES=$(dconf read /org/gnome/terminal/legacy/profiles:/list)
if ! echo "$CURRENT_PROFILES" | grep -q "$PROFILE_ID"; then
    if [ "$CURRENT_PROFILES" = "@as []" ] || [ -z "$CURRENT_PROFILES" ]; then
        NEW_PROFILES="['$PROFILE_ID']"
    else
        NEW_PROFILES=$(echo "$CURRENT_PROFILES" | sed "s/]$/, '$PROFILE_ID']/")
    fi
    dconf write /org/gnome/terminal/legacy/profiles:/list "$NEW_PROFILES"
fi

# Reset and configure profile
dconf reset -f /org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/

# Basic settings
dconf write /org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/visible-name "'Alacritty Theme'"
dconf write /org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/background-color "'rgb(20,25,31)'"
dconf write /org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/foreground-color "'rgb(255,255,255)'"
dconf write /org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/use-theme-colors false

# 16-color palette matching Alacritty
dconf write /org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/palette "['rgb(0,0,0)', 'rgb(255,85,85)', 'rgb(38,150,133)', 'rgb(255,184,108)', 'rgb(0,73,163)', 'rgb(98,114,164)', 'rgb(98,114,164)', 'rgb(174,194,224)', 'rgb(85,85,85)', 'rgb(255,85,85)', 'rgb(80,250,123)', 'rgb(255,243,97)', 'rgb(69,101,173)', 'rgb(255,121,198)', 'rgb(139,233,253)', 'rgb(255,255,255)']"

# Cursor and selection colors
dconf write /org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/cursor-colors-set true
dconf write /org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/cursor-background-color "'rgb(255,255,255)'"
dconf write /org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/cursor-foreground-color "'rgb(20,25,31)'"
dconf write /org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/highlight-colors-set true
dconf write /org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/highlight-background-color "'rgb(68,71,90)'"
dconf write /org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/highlight-foreground-color "'rgb(248,248,242)'"

# Font and transparency
dconf write /org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/font "'FiraMono Nerd Font 12'"
dconf write /org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/use-system-font false
dconf write /org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/use-transparent-background true
dconf write /org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/background-transparency-percent 15

# Set as default
dconf write /org/gnome/terminal/legacy/profiles:/default "'$PROFILE_ID'"

echo "✓ Gnome Terminal configured to match Alacritty"
echo "✓ Colors, font, and transparency applied"
echo "✓ Set as default profile"