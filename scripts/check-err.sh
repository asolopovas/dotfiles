#!/bin/bash

# Check for necessary dependencies
if ! command -v fzf &> /dev/null; then
    echo "fzf could not be found. Install with 'sudo apt install fzf' or your package manager."
    exit 1
fi

LOG_COMMANDS=(
    "System Errors (journalctl) => journalctl -p 3 -xb"
    "Kernel Errors (dmesg) => dmesg --level=err,warn"
    "Authentication Errors => grep -iE 'error|fail' /var/log/auth.log /var/log/secure 2>/dev/null"
    "Syslog Errors => grep -iE 'error|fail|critical' /var/log/syslog /var/log/messages 2>/dev/null"
    "Nginx Error Log => cat /var/log/nginx/error.log 2>/dev/null"
    "Apache Error Log => cat /var/log/apache2/error.log /var/log/httpd/error_log 2>/dev/null"
)

selected_command=$(printf '%s\n' "${LOG_COMMANDS[@]}" | fzf --prompt="Select logs to view: " --height=40% --reverse)

if [[ -z $selected_command ]]; then
    echo "No selection made. Exiting."
    exit 0
fi

# Corrected extraction with awk to handle multi-character delimiter
command=$(echo "$selected_command" | awk -F ' => ' '{print $2}')

# Execute command with less for scrolling convenience
eval "$command" | less -R

