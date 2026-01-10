#!/bin/bash
pkill -9 chrome 2>/dev/null
PROFILE_DIR="$HOME/.config/google-chrome/DebugProfile"
mkdir -p "$PROFILE_DIR"
google-chrome-stable --remote-debugging-port=9222 --user-data-dir="$PROFILE_DIR" --no-first-run --no-default-browser-check >/dev/null 2>&1 &
echo "Chrome debug started on port 9222 with profile: $PROFILE_DIR"
