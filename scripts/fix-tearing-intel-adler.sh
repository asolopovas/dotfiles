#!/bin/bash

# Update GRUB_CMDLINE_LINUX_DEFAULT variable in /etc/default/grub file
sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="i915.enable_psr=0 i915.enable_fbc=0"/' /etc/default/grub
# sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="i915.enable_psr=0"/' /etc/default/grub

# Regenerate GRUB configuration file
sudo update-grub

