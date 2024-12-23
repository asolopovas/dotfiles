#!/bin/bash

# Elevate privileges by prompting for root password if not already running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script requires root privileges. Please enter your password."
    exec sudo bash "$0" "$@"
fi

# Function to dynamically determine IP and configure netplan
set_dynamic_static_ip() {
    local INTERFACE="eth0"
    local CIDR="24"
    local IP_ADDRESS="$1"

    if [[ -z "$IP_ADDRESS" ]]; then
        echo "Usage: $0 <IP_ADDRESS>"
        exit 1
    fi

    # Get gateway based on provided IP
    local GATEWAY
    GATEWAY=$(echo "$IP_ADDRESS" | awk -F. '{print $1"."$2"."$3".1"}')

    # Define DNS servers (you can customize these)
    local DNS_SERVERS="192.168.1.1,192.168.0.1,8.8.8.8,8.8.4.4"

    # Generate the netplan configuration file
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
      nameservers:
        addresses: [$DNS_SERVERS]
      dhcp4: false
EOF

    # Fix permissions for the netplan configuration file
    chmod 600 /etc/netplan/01-netcfg.yaml
    chown root:root /etc/netplan/01-netcfg.yaml

    # Apply netplan configuration
    netplan apply

    # Secure the interface configuration
    ip addr flush dev $INTERFACE
    ip addr add $IP_ADDRESS/$CIDR dev $INTERFACE
    ip link set $INTERFACE up

    echo "Static IP configured for $INTERFACE: $IP_ADDRESS/$CIDR with gateway $GATEWAY and DNS $DNS_SERVERS"
}

# Execute the function with the provided argument
set_dynamic_static_ip "$1"
