#!/bin/bash

CREDENTIALS="$HOME/.claude/.credentials.json"
CR1="$HOME/.claude/cr1.json"
CR2="$HOME/.claude/cr2.json"

if [[ ! -f "$CREDENTIALS" || ! -f "$CR1" || ! -f "$CR2" ]]; then
    echo "Error: One or more required files do not exist."
    exit 1
fi

get_refresh_token() {
    jq -r '.claudeAiOauth.refreshToken' "$1"
}

REF_CRED=$(get_refresh_token "$CREDENTIALS")
REF_CR1=$(get_refresh_token "$CR1")
REF_CR2=$(get_refresh_token "$CR2")

if [[ "$REF_CRED" == "$REF_CR1" ]]; then
    cp "$CR2" "$CREDENTIALS"
    echo "Switched credentials to cr2.json"
elif [[ "$REF_CRED" == "$REF_CR2" ]]; then
    cp "$CR1" "$CREDENTIALS"
    echo "Switched credentials to cr1.json"
else
    echo "Warning: credentials.json does not match cr1.json or cr2.json based on refreshToken. No action taken."
fi
