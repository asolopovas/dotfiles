#!/bin/bash

xorg_server_dir=$(find /usr /lib /opt -name 'xorg-server.pc' -exec dirname {} \; 2>/dev/null)
export_line="export PKG_CONFIG_PATH=$xorg_server_dir/xorg-server.pc:\$PKG_CONFIG_PATH"

if grep -qF "$export_line" ~/.profile; then
  echo "PKG_CONFIG_PATH export already in ~/.profile"
else
  echo "$export_line" >> ~/.profile
  echo "Added PKG_CONFIG_PATH export to ~/.profile"
fi

nvidia_polkit="/usr/share/screen-resolution-extra/nvidia-polkit"
if [ -f "$nvidia_polkit" ]; then
  sudo chmod +x "$nvidia_polkit" && echo "Made $nvidia_polkit executable"
else
  echo "File $nvidia_polkit does not exist"
fi

xorg_conf="/etc/X11/xorg.conf"
if [ -f "$xorg_conf" ]; then
  sudo chmod 644 "$xorg_conf" && echo "Set permissions for $xorg_conf to 644"
else
  echo "File $xorg_conf does not exist"
fi
