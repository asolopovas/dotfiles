#!/bin/sh
# Set DPI based on hardware detection (ThinkPad vs Desktop)

# Check if running on any ThinkPad
if [ -f /sys/class/dmi/id/product_version ] && grep -q "ThinkPad" /sys/class/dmi/id/product_version 2>/dev/null; then
    # Laptop: 125% scaling (96 * 1.25 = 120)
    DPI=120
    CURSOR=28
else
    # Desktop: normal DPI  
    DPI=96
    CURSOR=24
fi

# Apply DPI settings
printf "Xft.dpi: %d\nXcursor.size: %d\n" "$DPI" "$CURSOR" | xrdb -merge

# Load remaining Xresources (excluding DPI and cursor size)
[ -f ~/.Xresources ] && grep -v -E "^(Xft.dpi:|Xcursor.size:)" ~/.Xresources | xrdb -merge