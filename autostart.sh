#!/bin/bash
~/dotfiles/scripts/ui-set-dpi-by-hardware.sh

~/dotfiles/scripts/ui-polybar-fonts.sh

session_id="${XDG_CURRENT_DESKTOP:-} ${DESKTOP_SESSION:-} ${GDMSESSION:-}"
shopt -s nocasematch
if [[ "$session_id" == *xmonad* ]] && command -v gnome-keyring-daemon &>/dev/null; then
    keyring_env=$(gnome-keyring-daemon --start --components=pkcs11,secrets,ssh 2>/dev/null || true)
    while IFS='=' read -r key value; do
        case "$key" in
            GNOME_KEYRING_CONTROL | SSH_AUTH_SOCK)
                export "$key=$value"
                ;;
        esac
    done <<<"$keyring_env"
fi
shopt -u nocasematch
unset keyring_env

run_if_exists() {
    if command -v "$1" &>/dev/null; then
        "$@" &
    fi
}

start_policykit_agent() {
    local agent
    for agent in lxqt-policykit-agent lxpolkit polkit-gnome-authentication-agent-1 /usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1 /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1; do
        if command -v "$agent" &>/dev/null; then
            "$agent" &
            return
        fi
        if [ -x "$agent" ]; then
            "$agent" &
            return
        fi
    done
}

if command -v picom &>/dev/null; then
    nohup picom --config "$HOME/.config/picom.conf" >/tmp/picom.log 2>&1 &
elif command -v fastcompmgr &>/dev/null; then
    nohup fastcompmgr -r 7 -l -7 -t -7 -i 1.0 -c -C >/dev/null 2>&1 &
fi
if [ -x "$HOME/.config/polybar/launch.sh" ]; then
    "$HOME/.config/polybar/launch.sh" >/tmp/polybar.log 2>&1 &
fi
if command -v cryptomator &>/dev/null; then
    nohup cryptomator >/tmp/cryptomator.log 2>&1 &
fi
case "${session_id,,}" in
    *xmonad*) ;;
    *) run_if_exists ulauncher --no-window-shadow --hide-window ;;
esac
run_if_exists flameshot
run_if_exists nm-applet
start_policykit_agent
if command -v blueman-applet &>/dev/null; then
    blueman-applet >/tmp/blueman.log 2>&1 &
fi
run_if_exists set-wallpaper
if command -v pgrep &>/dev/null; then
    pgrep -x dunst >/dev/null 2>&1 || run_if_exists dunst
else
    run_if_exists dunst
fi
if command -v telegram-desktop &>/dev/null; then
    telegram-desktop -startintray -- %u &
elif command -v telegram &>/dev/null; then
    telegram -startintray -- %u &
fi
if command -v insync &>/dev/null; then
    insync start &
fi
run_if_exists xset r rate 300 50
run_if_exists xsetroot -cursor_name left_ptr

if command -v xinput &>/dev/null; then
    touchpad_id=$(xinput list | awk '/Touch[Pp]ad|Track[Pp]ad/ && /pointer/ { sub(/.*id=/, ""); sub(/\t.*/, ""); print; exit }')
    if [ -n "$touchpad_id" ]; then
        xinput set-prop "$touchpad_id" "libinput Accel Speed" 0.4
    fi
    unset touchpad_id
fi

if command -v ibus-daemon &>/dev/null; then
    pkill -f 'ibus-daemon' 2>/dev/null
    ibus-daemon --xim --daemonize --replace --panel disable
fi

keyboard_layouts=$(gsettings get org.gnome.desktop.input-sources sources 2>/dev/null |
    grep -oE "'xkb', '[^']+'" | sed -E "s/.*'([^']+)'$/\1/" | paste -sd, -)
keyboard_options=$(gsettings get org.gnome.desktop.input-sources xkb-options 2>/dev/null |
    grep -oE "'[^']+'" | tr -d "'" | paste -sd, -)

if [[ " $session_id " == *xmonad* ]]; then
    keyboard_layouts=gb,ru
    keyboard_options=grp:win_space_toggle,terminate:ctrl_alt_bksp,grp_led:scroll
fi

if command -v setxkbmap &>/dev/null; then
    setxkbmap -layout "${keyboard_layouts:-gb}" -option '' ${keyboard_options:+-option "$keyboard_options"} &
fi

if command -v gxkb &>/dev/null; then
    if [[ " $session_id " == *xmonad* ]]; then
        mkdir -p "$HOME/.config/gxkb"
        cat >"$HOME/.config/gxkb/gxkb.cfg" <<EOF
[xkb config]
group_policy=2
default_group=0
never_modify_config=false
model=pc105
layouts=${keyboard_layouts:-gb,ru}
variants=,
toggle_option=${keyboard_options:-grp:win_space_toggle,terminate:ctrl_alt_bksp,grp_led:scroll}
compose_key_position=
EOF
    fi
    pkill -x gxkb 2>/dev/null
    gxkb &
fi
