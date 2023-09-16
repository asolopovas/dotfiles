#!/bin/bash

file="/etc/X11/xorg.conf.d/40-touchpad.conf"

sudo tee "$file" >/dev/null <<EOL
Section "InputClass"
    Identifier "SynPS/2 Synaptics TouchPad"
    MatchIsTouchpad "on"
    MatchDevicePath "/dev/input/event*"
    Driver "libinput"
    # Tapping
    Option "Tapping" "on"
    Option "TappingDrag" "on"
    # Scrolling
    Option "NaturalScrolling" "on"
    Option "AccelSpeed" "0.3"
    Option "ScrollPixelDistance" "25"
EndSection
EOL

