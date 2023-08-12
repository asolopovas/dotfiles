#!/usr/bin/env bash

CONFIG_DIR=$HOME/dotfiles/.config/polybar
THEME=minimal
CONFIG=$CONFIG_DIR/themes/$THEME/config.ini

polybar main -c $CONFIG_DIR &

killall polybar >/dev/null 2>&1
while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

net_interface=$(ip route show | grep default | awk '{print$5}')


# if command -v xrandr >/dev/null 2>&1; then
#     xrandr --query | grep " connected" | while read -r line; do
#         primary=$(echo $line | awk '{print$3}')
#         display=$(echo $line | awk '{print$1}')
#         user=$(whoami)

#         #   printf "Primary: $primary\n"
#         #   printf "Display: $display\n"
#         #   printf "User: $user\n"

#     done
# fi

CONFIG_DIR=$CONFIG_DIR MONITOR=$display polybar main -c $CONFIG --reload
