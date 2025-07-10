#!/bin/bash

# Define file paths
CREDENTIALS="$HOME/.claude/.credentials.json"
CR1="$HOME/.claude/.cr1.json"
CR2="$HOME/.claude/.cr2.json"

# Check if files exist
if [[ ! -f "$CREDENTIALS" || ! -f "$CR1" || ! -f "$CR2" ]]; then
    echo "Error: One or more required files do not exist."
    exit 1
fi

# Compare the credentials with cr1
if cmp -s "$CREDENTIALS" "$CR1"; then
    cp "$CR2" "$CREDENTIALS"
    echo "Switched credentials to cr2.json"
elif cmp -s "$CREDENTIALS" "$CR2"; then
    cp "$CR1" "$CREDENTIALS"
    echo "Switched credentials to cr1.json"
else
    echo "Warning: credentials.json does not match cr1.json or cr2.json. No action taken."
fi
