#!/bin/bash

# Set mouse acceleration speed for Logitech G305
# Usage: ./set-mouse-speed.sh [speed]
# Speed range: -1.0 (slowest) to 1.0 (fastest), default: -0.8

SPEED=${1:-"-0.8"}
DEVICE_NAME="Logitech G305"

# Find the device ID for the mouse
DEVICE_ID=$(xinput list | grep "$DEVICE_NAME" | grep "slave  pointer" | sed 's/.*id=\([0-9]*\).*/\1/')

if [ -z "$DEVICE_ID" ]; then
    echo "Error: Could not find $DEVICE_NAME"
    exit 1
fi

# Set the acceleration speed
xinput set-prop "$DEVICE_ID" "libinput Accel Speed" "$SPEED"

echo "Mouse speed set to $SPEED for $DEVICE_NAME (ID: $DEVICE_ID)"