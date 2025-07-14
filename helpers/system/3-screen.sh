#!/bin/sh

screens="eDP-1-1 HDMI-1-1 DP-1-1"
pos_x=0
cmd="xrandr"

for screen in $screens; do
    cmd="$cmd --output $screen --mode 1920x1080 --pos ${pos_x}x0 --rotate normal"
    pos_x=$(($pos_x + 1920))
done

eval $cmd
