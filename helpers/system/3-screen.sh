#!/bin/bash

screens="eDP-1-1 HDMI-1-1 DP-1-1"
pos_x=0

for screen in $screens; do
    xrandr --output $screen --mode 1920x1080 --pos ${pos_x}x0 --rotate normal
    pos_x=$(($pos_x + 1920))
done
