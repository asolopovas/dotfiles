#!/bin/bash

file="/etc/X11/xorg.conf.d/40-libinput.conf"

sudo tee "$file" >/dev/null <<EOL
Section "InputClass"
    Identifier "libinput touchpad catchall"
    MatchIsTouchpad "on"
    MatchDevicePath "/dev/input/event*"
    Driver "libinput"
    MatchIsTouchpad "on"
    Option "Tapping" "on"
    Option "TappingDrag" "on"
    Option "TappingDragLock" "off"
    Option "TappingButtonMapping" "1 0"
    Option "NaturalScrolling" "true"
    Option "DisableWhileTyping" "true"
    Option "ScrollMethod" "1 0 0"
    Option "ScrollFactor" "0.5"
    Option "ClickMethod" "1 0"
    Option "MiddleEmulation" "off"
    Option "AccelSpeed" "1.0"
    Option "AccelProfile" "1 0"
    Option "LeftHanded" "off"
    Option "SendEventsMode" "0 0"
    Option "ScrollingPixelDistance" "15"
    Option "HorizontalScroll" "on"
EndSection
EOL

