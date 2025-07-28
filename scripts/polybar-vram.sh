#!/bin/bash

# Get VRAM usage using nvidia-smi
if command -v nvidia-smi &> /dev/null; then
    # Get used and total VRAM in MiB
    vram_info=$(nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits | head -1)
    used=$(echo $vram_info | cut -d',' -f1 | tr -d ' ')
    total=$(echo $vram_info | cut -d',' -f2 | tr -d ' ')
    
    if [ -n "$used" ] && [ -n "$total" ]; then
        # Calculate percentage
        percentage=$(awk "BEGIN {printf \"%.0f\", ($used/$total)*100}")
        echo "${percentage}%"
    else
        echo "N/A"
    fi
else
    echo "N/A"
fi