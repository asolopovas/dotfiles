#!/bin/bash

nvidia_polkit=/usr/share/screen-resolution-extra/nvidia-polkit 
if [ -f $nvidia_polkit ]; then
  sudo chmod +x $nvidia_polkit
  echo "Made $nvidia_polkit executable"
else
  echo "File $nvidia_polkit does not exist"
fi

