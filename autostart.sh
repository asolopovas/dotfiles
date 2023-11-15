#!/bin/bash
gnome-keyring-daemon --start --components=pkcs11,secrets,ssh
.config/polybar/launch.sh > /tmp/polybar.log 2>&1 &
nohup cryptomator > /tmp/cryptomator.log 2>&1 &
flameshot &
nm-applet &
blueman-applet > /tmp/blueman.log 2>&1 &
set-wallpaper &
dunst &
telegram-desktop &
# setxkbmap -layout gb,ru -option 'grp:win_space_toggle'
insync start
