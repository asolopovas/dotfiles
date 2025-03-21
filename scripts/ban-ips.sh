#!/bin/bash

JAIL="plesk-permanent-ban"

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

# Match lines by pattern
MATCHED_LINES=$(grep "$PATTERN" "$LOG_FILE")
if [ -z "$MATCHED_LINES" ]; then
    echo "No lines found matching pattern '$PATTERN' in '$LOG_FILE'."
    exit 0
fi

# Extract IPs depending on format
RAW_IPS=$(echo "$MATCHED_LINES" | \
    sed -nE 's/.*client[: ]+([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)(:[0-9]+)?[].]*/\1/p' | \
    sort -u)

# Filter out excluded IPs
if [ ${#EXCLUDE_IPS[@]} -gt 0 ]; then
    for EXCL in "${EXCLUDE_IPS[@]}"; do
        RAW_IPS=$(echo "$RAW_IPS" | grep -v "^$EXCL$")
    done
fi

if [ -z "$RAW_IPS" ]; then
    echo "No IPs left to ban after filtering."
    exit 0
fi

echo "The following unique IPs matched the pattern and would be banned:"
echo "$RAW_IPS"
echo
read -p "Do you want to proceed with banning these IPs using jail '$JAIL'? (y/N): " CONFIRM

if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "$RAW_IPS" | while read -r IP; do
        echo "Banning IP: $IP using jail $JAIL"
        sudo fail2ban-client set "$JAIL" banip "$IP"
    done
    echo "✅ Banning completed."
else
    echo "❌ Operation canceled."
fi
