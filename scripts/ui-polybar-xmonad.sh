#!/bin/bash

declare -A screen_active_desktop

$HOME/go/bin/xmonad-log | while IFS= read -r line; do
    temp_line="$line"
    current_focused_screen=""

    if [[ $line =~ %\{F#2266d0\}\ ([0-9]+)_([0-9]+)\ %\{F-\} ]]; then
        current_focused_screen="${BASH_REMATCH[1]}"
    fi

    while [[ $temp_line =~ ([^%]*)%\{F#[0-9a-fA-F]+\}\ ([0-9]+)_([0-9]+)\ %\{F-\}(.*) ]] || [[ $temp_line =~ ([^%]*)%\{F#2266d0\}\ ([0-9]+)_([0-9]+)\ %\{F-\}(.*) ]]; do
        screen_id="${BASH_REMATCH[2]}"
        desktop_id="${BASH_REMATCH[3]}"
        screen_active_desktop[$screen_id]=$desktop_id
        temp_line="${BASH_REMATCH[1]}${BASH_REMATCH[4]}"
    done

    screens=()
    temp_line="$line"
    while [[ $temp_line =~ ([0-9]+)_([0-9]+) ]]; do
        screen_id="${BASH_REMATCH[1]}"
        screens+=("$screen_id")
        temp_line="${temp_line/${BASH_REMATCH[0]}/_PROCESSED_}"
    done

    if [[ ${#screens[@]} -gt 0 ]]; then
        mapfile -t sorted_screens < <(printf '%s\n' "${screens[@]}" | sort -nu)
    else
        sorted_screens=(0 1)
    fi

    display=""
    for i in "${!sorted_screens[@]}"; do
        screen="${sorted_screens[i]}"

        if [[ "$screen" == "$current_focused_screen" ]]; then
            display+="%{F#87ceeb}Screen $screen:%{F-} "
        else
            display+="Screen $screen: "
        fi

        for desktop in {1..9}; do
            if [[ "${screen_active_desktop[$screen]}" == "$desktop" ]]; then
                display+="%{F#ffe500}$desktop%{F-}"
            else
                display+="$desktop"
            fi
            if [[ $desktop -lt 9 ]]; then
                display+=" "
            fi
        done

        if [[ $i -lt $((${#sorted_screens[@]} - 1)) ]]; then
            display+=" | "
        fi
    done

    echo "$display"
done
