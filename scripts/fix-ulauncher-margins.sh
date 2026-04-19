#!/bin/bash

UI_FILE="/usr/share/ulauncher/ui/UlauncherWindow.ui"
PY_FILE="/usr/lib/python3/dist-packages/ulauncher/ui/windows/UlauncherWindow.py"

if [[ -f "$UI_FILE" ]]; then
    if grep -q 'id="body"' "$UI_FILE"; then
        sudo sed -i '/<object class="GtkBox" id="body">/,/<property name="orientation">/ {
            s/<property name="margin_left">[0-9]\+</<property name="margin_left">8</
            s/<property name="margin_right">[0-9]\+</<property name="margin_right">10</
            s/<property name="margin_top">[0-9]\+</<property name="margin_top">10</
            s/<property name="margin_bottom">[0-9]\+</<property name="margin_bottom">10</
        }' "$UI_FILE"
        echo "Ulauncher body margins patched (left:8 right:10 top:10 bottom:10)"
    else
        echo "UI file structure changed"
    fi
else
    echo "Ulauncher UI file not found: $UI_FILE"
fi

if [[ -f "$PY_FILE" ]]; then
    if grep -q "screen\['height'\] / 5" "$PY_FILE"; then
        sudo sed -i "s|screen\['height'\] / 5 + screen\['y'\]|screen['height'] / 2 - self.get_size()[1] / 2 + screen['y']|" "$PY_FILE"
        sudo find "$(dirname "$PY_FILE")" -name "*.pyc" -delete 2>/dev/null
        sudo find "$(dirname "$PY_FILE")/__pycache__" -name "*.pyc" -delete 2>/dev/null
        echo "Ulauncher window position patched to center"
    else
        echo "Window position already patched or code structure changed"
    fi
else
    echo "Ulauncher Python file not found: $PY_FILE"
fi
