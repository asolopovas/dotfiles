#!/bin/bash
~/dotfiles/scripts/ui-set-dpi-by-hardware.sh

~/dotfiles/scripts/ui-polybar-fonts.sh

session_id="${XDG_CURRENT_DESKTOP:-} ${DESKTOP_SESSION:-} ${GDMSESSION:-}"
shopt -s nocasematch
if [[ "$session_id" == *xmonad* ]]; then
    gnome-keyring-daemon --start --components=pkcs11,secrets,ssh
fi
shopt -u nocasematch

if command -v picom &>/dev/null; then
    nohup picom --config ~/.config/picom.conf >/tmp/picom.log 2>&1 &
elif command -v fastcompmgr &>/dev/null; then
    nohup fastcompmgr -r 7 -l -7 -t -7 -i 1.0 -c -C >/dev/null 2>&1 &
fi
.config/polybar/launch.sh >/tmp/polybar.log 2>&1 &
nohup cryptomator >/tmp/cryptomator.log 2>&1 &
ulauncher --no-window-shadow --hide-window &
flameshot &
nm-applet &
lxqt-policykit-agent &
blueman-applet >/tmp/blueman.log 2>&1 &
set-wallpaper &
dunst &
telegram-desktop -startintray -- %u &
insync start
xset r rate 300 50 &
xsetroot -cursor_name left_ptr &

if command -v ibus-daemon &>/dev/null; then
    pkill -f 'ibus-daemon' 2>/dev/null
    ibus-daemon --xim --daemonize --replace --panel disable
fi

if command -v gxkb &>/dev/null; then
    pkill -x gxkb 2>/dev/null
    (sleep 3; gxkb) &
fi

if command -v setxkbmap &>/dev/null; then
    layouts=$(gsettings get org.gnome.desktop.input-sources sources 2>/dev/null \
        | grep -oE "'xkb', '[^']+'" | sed -E "s/.*'([^']+)'$/\1/" | paste -sd, -)
    options=$(gsettings get org.gnome.desktop.input-sources xkb-options 2>/dev/null \
        | grep -oE "'[^']+'" | tr -d "'" | paste -sd, -)
    (sleep 2; setxkbmap -layout "${layouts:-gb}" -option '' ${options:+-option "$options"}) &
fi
