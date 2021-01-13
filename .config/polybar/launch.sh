#!/usr/bin/env bash

# Terminate already running bar instances
killall -q polybar
net_interface=$(ip route show | grep default | awk '{print$5}')
for i in /sys/class/hwmon/hwmon*/temp*_input; do 
  echo $i
  if [[ $i == *"hwmon0/temp1_input"* || $i == *"hwmon4/temp1_input"* ]]; then
    cpu_temp=$i
  fi
done


if type "xrandr"; then
  xrandr --query | grep " connected" |	while read -r line; do
  primary=$(echo $line | awk '{print$3}')
  display=$(echo $line | awk '{print$1}')
  user=$(whoami)

  if [ "$primary" == "primary" ] && [ $display == 'eDP-1' ]; then 
    CPU_TEMP=$cpu_temp	NETWORK_INTERFACE=$net_interface MONITOR=$display polybar --reload laptop > "/tmp/$user-polybar-laptop.log" 2>&1 &
  else 
    echo "loading main bar...\n"
    CPU_TEMP=$cpu_temp	NETWORK_INTERFACE=$net_interface MONITOR=$display polybar --reload main > "/tmp/$user-polybar-main.log" 2>&1 &
  fi
done
fi

