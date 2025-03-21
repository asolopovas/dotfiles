#!/bin/bash

JAIL="plesk-permanent-ban"

# Check usage
if [ $# -lt 2 ]; then
    echo "Usage: $0 <log_file> <pattern> [excluded_ip1 excluded_ip2 ...]"
    exit 1
fi

LOG_FILE="$1"
PATTERN="$2"
shift 2
EXCLUDE_IPS=("$@")

# Validate log file
if [ ! -f "$LOG_FILE" ] || [ ! -r "$LOG_FILE" ]; then
    echo "Error: File '$LOG_FILE' does not exist or is not readable."
    exit 1
fi

# Get matching lines
MATCHED_LINES=$(grep "$PATTERN" "$LOG_FILE")
if [ -z "$MATCHED_LINES" ]; then
    echo "No lines found matching pattern '$PATTERN' in '$LOG_FILE'."
    exit 0
fi

# Extract IPs based on log type
if echo "$MATCHED_LINES" | grep -q "\[client "; then
    # Apache error log format: [client x.x.x.x:port]
    RAW_IPS=$(echo "$MATCHED_LINES" | grep -oP '(?<=\[client )\d+\.\d+\.\d+\.\d+')
elif echo "$MATCHED_LINES" | grep -q "client:"; then
    # NGINX error log format: client: x.x.x.x
    RAW_IPS=$(echo "$MATCHED_LINES" | grep -oP '(?<=client: )\d+\.\d+\.\d+\.\d+')
else
    # Access logs: IP is the first field
    RAW_IPS=$(echo "$MATCHED_LINES" | awk '{print $1}')
fi

# Deduplicate
UNIQ_IPS=$(echo "$RAW_IPS" | sort -u)

# Exclude IPs
if [ ${#EXCLUDE_IPS[@]} -gt 0 ]; then
    for EXCL in "${EXCLUDE_IPS[@]}"; do
        UNIQ_IPS=$(echo "$UNIQ_IPS" | grep -v "^$EXCL$")
    done
fi

# Check if anything remains
if [ -z "$UNIQ_IPS" ]; then
    echo "No IPs left to ban after filtering."
    exit 0
fi

# Show and confirm
echo "The following unique IPs matched the pattern and would be banned:"
echo "$UNIQ_IPS"
echo
read -p "Do you want to proceed with banning these IPs using jail '$JAIL'? (y/N): " CONFIRM

if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "$UNIQ_IPS" | while read -r IP; do
        echo "Banning IP: $IP using jail $JAIL"
        sudo fail2ban-client set "$JAIL" banip "$IP"
    done
    echo "✅ Ba
