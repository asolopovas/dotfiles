#!/usr/bin/env bash

CONFIG_DIR=$HOME/dotfiles/config/polybar
THEME=minimal
CONFIG=$CONFIG_DIR/themes/$THEME/config.ini

killall polybar >/dev/null 2>&1
while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

net_interface=$(ip route show | grep default | awk '{print$5}')

CONFIG_DIR=$CONFIG_DIR MONITOR=$display polybar main -c $CONFIG --reload
