#!/bin/bash

# Check if a hostname is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <hostname>"
    exit 1
fi

# Define the hostname and file names
HOSTNAME=$1
CRT_FILE="${HOSTNAME}.crt"
KEY_FILE="${HOSTNAME}.key"

# Check if certificate and key files exist
if [ ! -f "$CRT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
    echo "Either $CRT_FILE or $KEY_FILE not found."
    exit 1
fi

# Run the whmapi1 command
whmapi1 --output=jsonpretty \
  installssl \
  domain="$HOSTNAME" \
  crt="$(cat $CRT_FILE)" \
  key="$(cat $KEY_FILE)"
