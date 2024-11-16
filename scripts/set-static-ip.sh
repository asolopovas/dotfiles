#!/bin/bash

set_static_ip() {
    local IP_ADDRESS="$1"
    local INTERFACE="eth0"
    local CIDR="24"

    if [[ -z "$IP_ADDRESS" ]]; then
        echo "Usage: $0 <IP_ADDRESS>"
        return 1
    fi

    sudo ip addr flush dev $INTERFACE
    sudo ip addr add $IP_ADDRESS/$CIDR dev $INTERFACE
    sudo ip link set $INTERFACE up

    echo "Static IP configured for $INTERFACE: $IP_ADDRESS/$CIDR"
}

set_static_ip "$1"
