#!/bin/bash

# Define the configuration file path
CONF_FILE="/etc/lightdm/lightdm.conf.d/50-screens.conf"

# Create the configuration content
echo "[Seat:*]" > "$CONF_FILE"
echo "display-setup-script=xrandr --output eDP-1-1 --mode 1920x1080 --pos 0x1080 --rotate normal --output HDMI-1-1 --mode 1920x1080 --pos 1920x0 --rotate normal --output DP-1-1 --primary --mode 1920x1080 --pos 0x0 --rotate normal --output DP-1-2 --off --output DP-1-3 --off --output DP-1-4 --off" >> "$CONF_FILE"

# Provide feedback
echo "Configuration file created at $CONF_FILE"
