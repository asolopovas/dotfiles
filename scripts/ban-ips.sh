#!/usr/bin/env bash

JAIL="plesk-permanent-ban"

# ------------------------------------------------------------
# Usage:
#   1) Single-file mode:
#       ban-ips.sh <log_file> <pattern> [excluded_ip1 excluded_ip2 ...]
#   2) Recursive-directory mode:
#       ban-ips.sh "<pattern>" --dir <directory> [excluded_ip1 excluded_ip2 ...]
# ------------------------------------------------------------

if [ $# -lt 2 ]; then
  echo "Usage:"
  echo "  $0 <log_file> <pattern> [excluded_ip1 ...]"
  echo "  OR"
  echo "  $0 \"<pattern>\" --dir <directory> [excluded_ip1 ...]"
  exit 1
fi

# ------------------------------------------------------------
# Parse arguments
# ------------------------------------------------------------
MODE="file"      # Default mode is single-file
SEARCH_DIR=""
LOG_FILE=""
PATTERN=""

if [ "$2" = "--dir" ]; then
    # Mode: directory (grep -r)
    MODE="dir"
    PATTERN="$1"
    SEARCH_DIR="$3"
    shift 3
    EXCLUDE_IPS=("$@")
else
    # Mode: single-file
    LOG_FILE="$1"
    PATTERN="$2"
    shift 2
    EXCLUDE_IPS=("$@")
fi

# ------------------------------------------------------------
# Gather matched lines
# ------------------------------------------------------------
if [ "$MODE" = "dir" ]; then
    # Validate directory
    if [ ! -d "$SEARCH_DIR" ] || [ ! -r "$SEARCH_DIR" ]; then
        echo "Error: Directory '$SEARCH_DIR' does not exist or is not readable."
        exit 1
    fi

    # Recursively grep. The output form is "filename:the_line_itself".
    # We do NOT strip the filename here, because we’ll just parse the entire line for IPs anyway.
    MATCHED_LINES=$(grep -r "$PATTERN" "$SEARCH_DIR" 2>/dev/null)
    if [ -z "$MATCHED_LINES" ]; then
        echo "No lines found matching pattern '$PATTERN' in directory '$SEARCH_DIR'."
        exit 0
    fi
else
    # Validate single log file
    if [ ! -f "$LOG_FILE" ] || [ ! -r "$LOG_FILE" ]; then
        echo "Error: File '$LOG_FILE' does not exist or is not readable."
        exit 1
    fi

    MATCHED_LINES=$(grep "$PATTERN" "$LOG_FILE")
    if [ -z "$MATCHED_LINES" ]; then
        echo "No lines found matching pattern '$PATTERN' in file '$LOG_FILE'."
        exit 0
    fi
fi

# ------------------------------------------------------------
# Extract *all* IPv4 addresses from the matched lines
#   (Even if they're not the first token or in [client ...] format)
# ------------------------------------------------------------
RAW_IPS=$(echo "$MATCHED_LINES" \
    | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}')

if [ -z "$RAW_IPS" ]; then
    echo "No IP addresses found in matching lines!"
    exit 0
fi

# ------------------------------------------------------------
# Remove duplicates
# ------------------------------------------------------------
UNIQ_IPS=$(echo "$RAW_IPS" | sort -u)

# ------------------------------------------------------------
# Exclude explicitly provided IPs
# ------------------------------------------------------------
if [ ${#EXCLUDE_IPS[@]} -gt 0 ]; then
    for EXCL in "${EXCLUDE_IPS[@]}"; do
        UNIQ_IPS=$(echo "$UNIQ_IPS" | grep -v "^$EXCL$")
    done
fi

# ------------------------------------------------------------
# If empty after exclusions, stop
# ------------------------------------------------------------
if [ -z "$UNIQ_IPS" ]; then
    echo "No IPs left to ban after filtering."
    exit 0
fi

# ------------------------------------------------------------
# Show results & prompt user
# ------------------------------------------------------------
echo "The following unique IPs matched the pattern and would be banned:"
echo "$UNIQ_IPS"
echo
read -p "Do you want to proceed with banning these IPs using jail '$JAIL'? (y/N): " CONFIRM

# ------------------------------------------------------------
# Ban if confirmed
# ------------------------------------------------------------
if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    while read -r IP; do
        echo "Banning IP: $IP using jail $JAIL"
        sudo fail2ban-client set "$JAIL" banip "$IP"
    done <<< "$UNIQ_IPS"
    echo "✅ Banning completed."
else
    echo "❌ Operation canceled."
fi
