#!/bin/bash

# Get VRAM usage using nvidia-smi
if command -v nvidia-smi &> /dev/null; then
    # Get used and total VRAM in MiB
    vram_info=$(nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits | head -1)
    used=$(echo $vram_info | cut -d',' -f1 | tr -d ' ')
    total=$(echo $vram_info | cut -d',' -f2 | tr -d ' ')

    if [ -n "$used" ] && [ -n "$total" ]; then
        # Convert MiB to GiB with 1 decimal place
        used_gib=$(awk "BEGIN {printf \"%.1f\", $used/1024}")

        # Calculate percentage for the bar
        percentage=$(awk "BEGIN {printf \"%.0f\", ($used/$total)*100}")

        # Create bar visualization (5 segments)
        bar_width=4
        filled=$(awk "BEGIN {printf \"%.0f\", ($percentage * $bar_width / 100)}")

        # Color based on percentage
        if [ $percentage -ge 90 ]; then
            color="#ff5555"  # red
        elif [ $percentage -ge 70 ]; then
            color="#f5a70a"  # orange
        elif [ $percentage -ge 50 ]; then
            color="#557755"  # dark green
        else
            color="#55aa55"  # green
        fi

        bar=""
        for ((i=1; i<=$bar_width; i++)); do
            if [ $i -le $filled ]; then
                bar="${bar}%{F${color}}▐%{F-}"
            else
                bar="${bar}%{F#444444}▐%{F-}"
            fi
        done

        echo "${used_gib} GiB ${bar}"
    else
        echo "N/A"
    fi
else
    echo "N/A"
fi
