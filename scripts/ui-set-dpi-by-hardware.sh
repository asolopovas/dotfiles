#!/bin/bash

if [ -f /sys/class/dmi/id/product_version ] && grep -q "ThinkPad" /sys/class/dmi/id/product_version 2>/dev/null; then
    DPI=120
    CURSOR=28
else
    DPI=96
    CURSOR=24
fi

printf "Xft.dpi: %d\nXcursor.size: %d\n" "$DPI" "$CURSOR" | xrdb -merge

[ -f ~/.Xresources ] && grep -v -E "^(Xft.dpi:|Xcursor.size:)" ~/.Xresources | xrdb -merge
