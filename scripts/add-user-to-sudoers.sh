#!/bin/bash

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Requesting elevated privileges..."
    sudo "$0"  # Re-run this script with sudo
    exit $?
fi

# Get the current username
USER_NAME="${SUDO_USER:-$(whoami)}"

echo 'Defaults !tty_tickets' > /etc/sudoers.d/${USER_NAME}.sudoers

newStr="${USER_NAME} ALL=(ALL:ALL) NOPASSWD: /usr/sbin/shutdown,/usr/sbin/reboot,/usr/bin/mount,/usr/bin/umount,/usr/bin/apt update -y,/usr/bin/apt upgrade -y"
echo "${newStr}" >> /etc/sudoers.d/${USER_NAME}.sudoers

chmod 440 /etc/sudoers.d/${USER_NAME}.sudoers
