#!/bin/bash

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Use: sudo $0 <IP_ADDRESS>"
    exit 1
fi

set_static_ip() {
    local IP_ADDRESS="$1"
    local INTERFACE="eth0"
    local CIDR="24"

    if [[ -z "$IP_ADDRESS" ]]; then
        echo "Usage: $0 <IP_ADDRESS>"
        return 1
    fi

    # Backup existing Netplan configuration
    cp /etc/netplan/*.yaml /etc/netplan/backup-$(date +%F-%H-%M-%S).yaml

    # Create a new Netplan configuration
    cat <<EOF > /etc/netplan/01-netcfg.yaml
network:
  version: 2
  ethernets:
    $INTERFACE:
      addresses:
        - $IP_ADDRESS/$CIDR
      dhcp4: false
EOF
    netplan apply

    # Secure file permissions
    chmod 600 /etc/netplan/*
    chown root:root /etc/netplan/*

    # Configure the interface
    ip addr flush dev $INTERFACE
    ip addr add $IP_ADDRESS/$CIDR dev $INTERFACE
    ip link set $INTERFACE up

    echo "Static IP configured for $INTERFACE: $IP_ADDRESS/$CIDR"
}

set_static_ip "$1"
