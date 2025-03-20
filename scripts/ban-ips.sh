#!/bin/bash

# Define the correct Fail2Ban jail (adjust as needed)
JAIL="plesk-wordpress"  # Change to plesk-permanent-ban if needed

# Check if the user provided an input file
if [ $# -ne 1 ]; then
    echo "Usage: $0 <ip_list_file>"
    exit 1
fi

IP_FILE="$1"

# Check if the file exists and is readable
if [ ! -f "$IP_FILE" ] || [ ! -r "$IP_FILE" ]; then
    echo "Error: File '$IP_FILE' does not exist or is not readable."
    exit 1
fi

# Read and ban each unique IP from the file
sort -u "$IP_FILE" | while read -r IP; do
    if [[ -n "$IP" ]]; then
        echo "Banning IP: $IP using jail $JAIL"
        sudo fail2ban-client set $JAIL banip $IP
    fi
done

echo "All IPs from '$IP_FILE' have been banned under the jail $JAIL."

