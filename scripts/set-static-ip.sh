#!/bin/bash

# Function to set a static IP for eth0 in WSL
set_static_ip() {
    local IP_ADDRESS="$1"
    local INTERFACE="eth0"
    local CIDR="24" # Adjust based on your subnet mask (e.g., 24 for 255.255.255.0)

    if [[ -z "$IP_ADDRESS" ]]; then
        echo "Usage: $0 <IP_ADDRESS>"
        return 1
    fi

    # Backup existing Netplan configuration
    sudo cp /etc/netplan/*.yaml /etc/netplan/backup-$(date +%F-%H-%M-%S).yaml

    # Create a new Netplan configuration
    cat <<EOF | sudo tee /etc/netplan/01-netcfg.yaml > /dev/null
network:
  version: 2
  ethernets:
    $INTERFACE:
      addresses:
        - $IP_ADDRESS/$CIDR
      dhcp4: false
EOF

    # Apply the new configuration
    sudo netplan apply

    echo "Static IP configuration applied for $INTERFACE: $IP_ADDRESS"
}

# Call the function with the provided argument
set_static_ip "$1"

