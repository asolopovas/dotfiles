#!/usr/bin/env bash

JAIL="plesk-permanent-ban"

# -- USAGE CHECK --
if [ $# -lt 2 ]; then
    echo "Usage: $0 <log_file> <pattern> [excluded_ip1 excluded_ip2 ...]"
    exit 1
fi

LOG_FILE="$1"
PATTERN="$2"
shift 2
EXCLUDE_IPS=("$@")

# -- VALIDATE LOG FILE --
if [ ! -f "$LOG_FILE" ] || [ ! -r "$LOG_FILE" ]; then
    echo "Error: File '$LOG_FILE' does not exist or is not readable."
    exit 1
fi

# -- GRAB ONLY LINES THAT MATCH THE PATTERN --
MATCHED_LINES=$(grep "$PATTERN" "$LOG_FILE")
if [ -z "$MATCHED_LINES" ]; then
    echo "No lines found matching pattern '$PATTERN' in '$LOG_FILE'."
    exit 0
fi

# -- DETECT LOG TYPE AND EXTRACT IPs --
if echo "$MATCHED_LINES" | grep -q "\[client "; then
    # Apache error log format: [client x.x.x.x:port]
    # Use sed to capture just the IP before the colon
    RAW_IPS=$(echo "$MATCHED_LINES" | sed -nE 's/.*\[client ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+):[0-9]+\].*/\1/p')
elif echo "$MATCHED_LINES" | grep -q "client:"; then
    # NGINX error log format: client: x.x.x.x
    RAW_IPS=$(echo "$MATCHED_LINES" | sed -nE 's/.*client: ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+).*/\1/p')
else
    # Apache access log (or similar), IP as first field
    RAW_IPS=$(echo "$MATCHED_LINES" | awk '{print $1}')
fi

# -- REMOVE DUPLICATES --
UNIQ_IPS=$(echo "$RAW_IPS" | sort -u)

# -- EXCLUDE ANY IPs PASSED AS EXTRA ARGS --
if [ ${#EXCLUDE_IPS[@]} -gt 0 ]; then
    for EXCL in "${EXCLUDE_IPS[@]}"; do
        UNIQ_IPS=$(echo "$UNIQ_IPS" | grep -v "^$EXCL$")
    done
fi

# -- IF EMPTY AFTER EXCLUSION, STOP --
if [ -z "$UNIQ_IPS" ]; then
    echo "No IPs left to ban after filtering."
    exit 0
fi

# -- SHOW RESULTS & PROMPT --
echo "The following unique IPs matched the pattern and would be banned:"
echo "$UNIQ_IPS"
echo
read -p "Do you want to proceed with banning these IPs using jail '$JAIL'? (y/N): " CONFIRM

# -- BAN IF CONFIRMED --
if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    while read -r IP; do
        echo "Banning IP: $IP using jail $JAIL"
        sudo fail2ban-client set "$JAIL" banip "$IP"
    done <<< "$UNIQ_IPS"
    echo "✅ Banning completed."
else
    echo "❌ Operation canceled."
fi
