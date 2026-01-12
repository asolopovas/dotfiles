#!/bin/bash
set -eu

log_dir="${LOG_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/chrome-debug}"
profile_dir="${PROFILE_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/google-chrome/DebugProfile}"
chrome_bin="${CHROME_BIN:-}"

die() {
    echo "chrome-debug: $*" >&2
    exit 1
}

ensure_writable_dir() {
    dir_path="$1"
    mkdir -p "$dir_path" 2>/dev/null || die "cannot create directory: $dir_path"
    [ -w "$dir_path" ] || die "directory not writable: $dir_path"
}

start_chrome() {
    if [ -z "$chrome_bin" ]; then
        chrome_bin="$(command -v google-chrome-stable 2>/dev/null || true)"
    fi
    [ -n "$chrome_bin" ] || die "google-chrome-stable not found in PATH"

    ensure_writable_dir "$log_dir"
    ensure_writable_dir "$profile_dir"

    pkill -9 -f "chrome.*--remote-debugging-port=9222" 2>/dev/null || true
    sleep 1
    nohup "$chrome_bin" \
        --remote-debugging-port=9222 \
        --user-data-dir="$profile_dir" \
        --no-first-run \
        --no-default-browser-check \
        --disable-default-apps \
        --noerrdialogs \
        >"$log_dir/chrome.log" 2>&1 &
    disown
    echo "Chrome debug started on port 9222 with profile: $profile_dir"
    echo "Log: $log_dir/chrome.log"
}

kill_chrome() {
    pkill -9 -f "chrome.*--remote-debugging-port=9222" 2>/dev/null || true
    echo "Chrome killed"
}

if [ "${1:-}" = "--kill" ]; then
    kill_chrome
else
    start_chrome
fi
