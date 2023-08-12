#!/usr/bin/env bash
gnome-keyring-daemon --start --components=pkcs11,secrets,ssh
.config/polybar/launch.sh &
nohup cryptomator &
flameshot &
nm-applet &
blueman-appletk
setbg &
insync start

