#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../../globals.sh"

installPackages gxkb ibus x11-xkb-utils

gsettings set org.gnome.desktop.input-sources sources "[('xkb','gb'),('xkb','ru')]"
gsettings set org.gnome.desktop.input-sources xkb-options "['grp:win_space_toggle','terminate:ctrl_alt_bksp','grp_led:scroll']"
gsettings set org.freedesktop.ibus.general.hotkey triggers "@as []"
gsettings set org.gnome.desktop.wm.keybindings switch-input-source "@as []"
gsettings set org.gnome.desktop.wm.keybindings switch-input-source-backward "@as []"

mkdir -p "$HOME/.config/gxkb"
cat >"$HOME/.config/gxkb/gxkb.cfg" <<'EOF'
[xkb config]
group_policy=2
default_group=0
never_modify_config=false
model=pc105
layouts=gb,ru
variants=,
toggle_option=grp:win_space_toggle,terminate:ctrl_alt_bksp,grp_led:scroll
compose_key_position=
EOF
