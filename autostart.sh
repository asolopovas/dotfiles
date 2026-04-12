#!/bin/bash
# Set DPI based on hardware (laptop vs desktop)
~/dotfiles/scripts/ui-set-dpi-by-hardware.sh

# Generate polybar font configuration based on current environment
~/dotfiles/scripts/ui-polybar-fonts.sh

gnome-keyring-daemon --start --components=pkcs11,secrets,ssh
# Start compositor (picom preferred, fallback to fastcompmgr)
if command -v picom &> /dev/null; then
    nohup picom --config ~/.config/picom.conf > /tmp/picom.log 2>&1 &
elif command -v fastcompmgr &> /dev/null; then
    nohup fastcompmgr -r 7 -l -7 -t -7 -i 1.0 -c -C > /dev/null 2>&1 &
fi
.config/polybar/launch.sh > /tmp/polybar.log 2>&1 &
nohup cryptomator > /tmp/cryptomator.log 2>&1 &
ulauncher --no-window-shadow --hide-window &
flameshot &
nm-applet &
blueman-applet > /tmp/blueman.log 2>&1 &
set-wallpaper &
dunst &
telegram-desktop -startintray -- %u &
insync start
xset r rate 300 50 &
xsetroot -cursor_name left_ptr &
