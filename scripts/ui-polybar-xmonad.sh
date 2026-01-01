#!/bin/bash

# Script to format xmonad log output for polybar
# Shows all screens with all desktops 1-9, highlighting active ones
# The active workspace is highlighted with %{F#2266d0} in xmonad-log output

# Track active desktops for each screen
declare -A screen_active_desktop

$HOME/go/bin/xmonad-log | while IFS= read -r line; do
    # Extract all screen-desktop pairs from the line and find active workspaces
    temp_line="$line"
    current_focused_screen=""
    
    # First, find the currently focused screen (highlighted with #2266d0)
    if [[ $line =~ %\{F#2266d0\}\ ([0-9]+)_([0-9]+)\ %\{F-\} ]]; then
        current_focused_screen="${BASH_REMATCH[1]}"
    fi
    
    # Parse all workspaces and identify active ones
    while [[ $temp_line =~ ([^%]*)%\{F#[0-9a-fA-F]+\}\ ([0-9]+)_([0-9]+)\ %\{F-\}(.*) ]] || [[ $temp_line =~ ([^%]*)%\{F#2266d0\}\ ([0-9]+)_([0-9]+)\ %\{F-\}(.*) ]]; do
        screen_id="${BASH_REMATCH[2]}"
        desktop_id="${BASH_REMATCH[3]}"
        # Update active desktop for this screen
        screen_active_desktop[$screen_id]=$desktop_id
        temp_line="${BASH_REMATCH[1]}${BASH_REMATCH[4]}"
    done
    
    # Extract all screens mentioned in the original line
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
        
        # Highlight currently focused screen name in soft blue
        if [[ "$screen" == "$current_focused_screen" ]]; then
            display+="%{F#87ceeb}Screen $screen:%{F-} "
        else
            display+="Screen $screen: "
        fi
        
        # Show desktops 1-9 for this screen
        for desktop in {1..9}; do
            if [[ "${screen_active_desktop[$screen]}" == "$desktop" ]]; then
                # Highlight active desktop with #ffe500 color
                display+="%{F#ffe500}$desktop%{F-}"
            else
                display+="$desktop"
            fi
            # Add separator between desktop numbers
            if [[ $desktop -lt 9 ]]; then
                display+=" "
            fi
        done
        
        # Add separator between screens if not last
        if [[ $i -lt $((${#sorted_screens[@]} - 1)) ]]; then
            display+=" | "
        fi
    done
    
    echo "$display"
done