#!/bin/bash
wgetPath=/home/andrius/.config/wget/

curl -fsSLO https://raw.githubusercontent.com/pimlie/ubuntu-mainline-kernel.sh/master/ubuntu-mainline-kernel.sh
sudo install ubuntu-mainline-kernel.sh /usr/local/bin/
