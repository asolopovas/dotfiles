#!/bin/bash

# Script to format xmonad log output for polybar
# Converts xmonad-log output to "Screen: X - Desktop Y" format
# The active workspace is highlighted with %{F#2266d0} in xmonad-log output

$HOME/go/bin/xmonad-log | while IFS= read -r line; do
    # Look for the highlighted workspace pattern %{F#2266d0} X_Y %{F-}
    if [[ $line =~ %\{F#2266d0\}\ ([0-9]+)_([0-9]+)\ %\{F-\} ]]; then
        screen_id="${BASH_REMATCH[1]}"
        desktop_n="${BASH_REMATCH[2]}"
        echo "Screen: $screen_id - Desktop $desktop_n"
    # Fallback: if no highlighted pattern, look for any workspace pattern
    elif [[ $line =~ ([0-9]+)_([0-9]+) ]]; then
        screen_id="${BASH_REMATCH[1]}"
        desktop_n="${BASH_REMATCH[2]}"
        echo "Screen: $screen_id - Desktop $desktop_n"
    else
        # Default fallback
        echo "Screen: ? - Desktop ?"
    fi
done