#!/bin/bash

# Define the configuration file path and name
config_file="/etc/X11/xorg.conf.d/40-libinput.conf"

# Create or overwrite the configuration file with the required settings
echo "Creating configuration file for natural scrolling: $config_file"

sudo bash -c "cat > $config_file <<EOF
Section \"InputClass\"
    Identifier \"libinput touchpad catchall\"
    MatchIsTouchpad \"on\"
    MatchDevicePath \"/dev/input/event*\"
    Driver \"libinput\"
    Option \"NaturalScrolling\" \"true\"
EndSection
EOF"

echo "Configuration file created successfully."

# Optional: Uncomment the following line to restart the X11 session automatically
# sudo systemctl restart gdm3

