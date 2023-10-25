#!/bin/bash
xrandr --output DP-2 --primary --mode 1920x1080 --pos 0x0 --output DP-0 --mode 1920x1080 --pos 1920x0

gnome-keyring-daemon --start --components=pkcs11,secrets,ssh
.config/polybar/launch.sh > /tmp/polybar.log 2>&1 &
nohup cryptomator > /tmp/cryptomator.log 2>&1 &
flameshot &
nm-applet &
blueman-applet > /tmp/blueman.log 2>&1 &
set-wallpaper &
dunst &
insync start

