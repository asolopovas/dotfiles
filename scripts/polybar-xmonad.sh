#!/bin/bash

# Script to format xmonad log output for polybar
# Shows all screens with all desktops 1-8, highlighting active ones
# The active workspace is highlighted with %{F#2266d0} in xmonad-log output

$HOME/go/bin/xmonad-log | while IFS= read -r line; do
    # Extract active screen and desktop from highlighted workspace
    active_screen=""
    active_desktop=""
    if [[ $line =~ %\{F#2266d0\}\ ([0-9]+)_([0-9]+)\ %\{F-\} ]]; then
        active_screen="${BASH_REMATCH[1]}"
        active_desktop="${BASH_REMATCH[2]}"
    fi
    
    # Extract all screens mentioned in the line
    screens=()
    temp_line="$line"
    while [[ $temp_line =~ ([0-9]+)_([0-9]+) ]]; do
        screen_id="${BASH_REMATCH[1]}"
        screens+=("$screen_id")
        # Remove the matched pattern to find next occurrence
        temp_line="${temp_line/${BASH_REMATCH[0]}/_PROCESSED_}"
    done
    
    # Remove duplicates and sort screens
    if [[ ${#screens[@]} -gt 0 ]]; then
        sorted_screens=($(printf '%s\n' "${screens[@]}" | sort -nu))
    else
        # Fallback: assume screens 0 and 1 if none detected
        sorted_screens=(0 1)
    fi
    
    # Build display string for all screens
    display=""
    for i in "${!sorted_screens[@]}"; do
        screen="${sorted_screens[i]}"
        display+="Screen $screen: "
        
        # Show desktops 1-8 for this screen
        for desktop in {1..8}; do
            if [[ "$screen" == "$active_screen" && "$desktop" == "$active_desktop" ]]; then
                # Highlight active desktop with #ffe500 color
                display+="%{F#ffe500}$desktop%{F-}"
            else
                display+="$desktop"
            fi
            # Add separator between desktop numbers
            if [[ $desktop -lt 8 ]]; then
                display+=" "
            fi
        done
        
        # Add separator between screens if not last
        if [[ $i -lt $((${#sorted_screens[@]} - 1)) ]]; then
            display+="  |  "
        fi
    done
    
    echo "$display"
done