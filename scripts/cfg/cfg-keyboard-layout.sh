#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/../../globals.sh"

installPackages gxkb ibus x11-xkb-utils

gsettings set org.gnome.desktop.input-sources sources "[('xkb','gb'),('xkb','ru')]"
gsettings set org.gnome.desktop.input-sources xkb-options "['grp:win_space_toggle','terminate:ctrl_alt_bksp','grp_led:scroll']"
gsettings set org.freedesktop.ibus.general.hotkey triggers "@as []"
gsettings set org.gnome.desktop.wm.keybindings switch-input-source "@as []"
gsettings set org.gnome.desktop.wm.keybindings switch-input-source-backward "@as []"
