#!/bin/bash

JAIL="plesk-permanent-ban"

if [ $# -ne 2 ]; then
    echo "Usage: $0 <log_file> <pattern>"
    exit 1
fi

LOG_FILE="$1"
PATTERN="$2"

# Validate file
if [ ! -f "$LOG_FILE" ] || [ ! -r "$LOG_FILE" ]; then
    echo "Error: File '$LOG_FILE' does not exist or is not readable."
    exit 1
fi

# Extract only the first field (the real IP), from lines that match the pattern
MATCHING_IPS=$(grep "$PATTERN" "$LOG_FILE" | awk '{print $1}' | sort -u)

if [ -z "$MATCHING_IPS" ]; then
    echo "No IPs found matching pattern '$PATTERN' in '$LOG_FILE'."
    exit 0
fi

echo "The following unique IPs matched the pattern and would be banned:"
echo "$MATCHING_IPS"
echo
read -p "Do you want to proceed with banning these IPs using jail '$JAIL'? (y/N): " CONFIRM

if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "$MATCHING_IPS" | while read -r IP; do
        echo "Banning IP: $IP using jail $JAIL"
        sudo fail2ban-client set "$JAIL" banip "$IP"
    done
    echo "✅ Banning completed."
else
    echo "❌ Operation canceled."
fi
