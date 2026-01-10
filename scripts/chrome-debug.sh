#!/bin/bash
LOG_DIR="$HOME/.logs/chrome-debug"
mkdir -p "$LOG_DIR"
PROFILE_DIR="$HOME/.config/google-chrome/DebugProfile"

start_chrome() {
    pkill -9 chrome 2>/dev/null
    sleep 1
    mkdir -p "$PROFILE_DIR"
    google-chrome-stable --remote-debugging-port=9222 --user-data-dir="$PROFILE_DIR" --no-first-run --no-default-browser-check >"$LOG_DIR/chrome.log" 2>&1 &
    echo "Chrome debug started on port 9222 with profile: $PROFILE_DIR"
    echo "Log: $LOG_DIR/chrome.log"
}

kill_chrome() {
    pkill -9 chrome 2>/dev/null
    echo "Chrome killed"
}

if [[ "$1" == "--kill" ]]; then
    kill_chrome
else
    start_chrome
fi
