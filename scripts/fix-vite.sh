#!/bin/bash

echo "Please enter your sudo password: "
sudo -v

while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

echo "* - nofile 10000" | sudo tee -a /etc/security/limits.conf
echo "fs.inotify.max_queued_events=16384" | sudo tee -a /etc/sysctl.conf
echo "fs.inotify.max_user_instances=8192" | sudo tee -a /etc/sysctl.conf
echo "fs.inotify.max_user_watches=524288" | sudo tee -a /etc/sysctl.conf

sudo sysctl -p
