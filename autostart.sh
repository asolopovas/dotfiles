#!/bin/bash
gnome-keyring-daemon --start --components=pkcs11,secrets,ssh
picom &
.config/polybar/launch.sh > /tmp/polybar.log 2>&1 &
nohup cryptomator > /tmp/cryptomator.log 2>&1 &
flameshot &
nm-applet &
blueman-applet > /tmp/blueman.log 2>&1 &
set-wallpaper &
dunst &
telegram-desktop -startintray -- %u &
insync start
xset r rate 300 50 &
xsetroot -cursor_name left_ptr &
