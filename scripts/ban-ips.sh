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

if [ ! -f "$LOG_FILE" ] || [ ! -r "$LOG_FILE" ]; then
    echo "Error: File '$LOG_FILE' does not exist or is not readable."
    exit 1
fi

# Detect format: check for "client:" vs common log format
if grep -q "client:" "$LOG_FILE"; then
    # Extract IP from error logs
    RAW_IPS=$(grep "$PATTERN" "$LOG_FILE" | sed -n 's/.*client: \([0-9.]*\).*/\1/p')
else
    # Extract IP from access logs (first field)
    RAW_IPS=$(grep "$PATTERN" "$LOG_FILE" | awk '{print $1}')
fi

# Remove duplicates
UNIQ_IPS=$(echo "$RAW_IPS" | sort -u)

# Exclude any provided IPs
if [ ${#EXCLUDE_IPS[@]} -gt 0 ]; then
    for EXCL in "${EXCLUDE_IPS[@]}"; do
        UNIQ_IPS=$(echo "$UNIQ_IPS" | grep -v "^$EXCL$")
    done
fi

if [ -z "$UNIQ_IPS" ]; then
    echo "No IPs left to ban after filtering."
    exit 0
fi

echo "The following unique IPs matched the pattern and would be banned:"
echo "$UNIQ_IPS"
echo
read -p "Do you want to proceed with banning these IPs using jail '$JAIL'? (y/N): " CONFIRM

if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "$UNIQ_IPS" | while read -r IP; do
        echo "Banning IP: $IP using jail $JAIL"
        sudo fail2ban-client set "$JAIL" banip "$IP"
    done
    echo "✅ Banning completed."
else
    echo "❌ Operation canceled."
fi
