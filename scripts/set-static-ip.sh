#!/bin/bash

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

    local GATEWAY
    GATEWAY=$(echo "$IP_ADDRESS" | awk -F. '{print $1"."$2"."$3".1"}')

    cat <<EOF > /etc/netplan/01-netcfg.yaml
network:
  version: 2
  ethernets:
    $INTERFACE:
      addresses:
        - $IP_ADDRESS/$CIDR
      routes:
        - to: 0.0.0.0/0
          via: $GATEWAY
      dhcp4: false
EOF
    netplan apply

    chown root:root /etc/netplan/*
    chmod 600 /etc/netplan/*

    ip addr flush dev $INTERFACE
    ip addr add $IP_ADDRESS/$CIDR dev $INTERFACE
    ip link set $INTERFACE up

    echo "Static IP configured for $INTERFACE: $IP_ADDRESS/$CIDR with gateway $GATEWAY"
}

set_static_ip "$1"
