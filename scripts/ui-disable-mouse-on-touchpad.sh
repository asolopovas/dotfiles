#!/bin/bash

#create the udev rule file
touchpad_rule="/etc/udev/rules.d/01-touchpad.rules"
xauthority=/home/$(whoami)/.Xauthority
sudo touch $touchpad_rule
sudo chmod 666 $touchpad_rule

template='SUBSYSTEM=="input", KERNEL=="mouse[0-9]*", ACTION=="add", ENV{DISPLAY}=":0", ENV{XAUTHORITY}="/home/username/.Xauthority", RUN+="/usr/bin/synclient TouchpadOff=1"'

echo $template | sed -e "s/username/$(whoami)/" | sudo tee $touchpad_rule
echo $template | sed -e "s/username/$(whoami)/" | sed -e 's/add/remove/' -e 's/TouchpadOff=1/TouchpadOff=0/' | sudo tee -a $touchpad_rule

# reload the udev rules
sudo udevadm control --reload-rules

