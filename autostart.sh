#!/bin/bash
~/dotfiles/scripts/ui-set-dpi-by-hardware.sh

~/dotfiles/scripts/ui-polybar-fonts.sh

session_id="${XDG_CURRENT_DESKTOP:-} ${DESKTOP_SESSION:-} ${GDMSESSION:-}"
shopt -s nocasematch
if [[ "$session_id" == *xmonad* ]] && command -v gnome-keyring-daemon &>/dev/null; then
	while IFS='=' read -r key value; do
		case "$key" in
		GNOME_KEYRING_CONTROL | SSH_AUTH_SOCK)
			export "$key=$value"
			;;
		esac
	done < <(gnome-keyring-daemon --start --components=pkcs11,secrets,ssh)
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
