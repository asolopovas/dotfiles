#!/bin/bash
set -euo pipefail

if ! command -v gsettings &>/dev/null; then
    echo "gsettings not available, skipping" >&2
    exit 0
fi

gsettings set org.gnome.desktop.input-sources sources "[('xkb','gb'),('xkb','ru')]"
gsettings set org.gnome.desktop.input-sources xkb-options "['grp:win_space_toggle','terminate:ctrl_alt_bksp','grp_led:scroll']"

gsettings set org.freedesktop.ibus.general.hotkey triggers "@as []"
gsettings set org.gnome.desktop.wm.keybindings switch-input-source "@as []"
gsettings set org.gnome.desktop.wm.keybindings switch-input-source-backward "@as []"

echo "configured: gb,ru with Super+Space toggle (XKB-level, not ibus)"
