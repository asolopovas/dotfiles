#!/bin/bash

# Check dependencies
for cmd in fzf less sudo; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "$cmd is not installed. Please install it first."
        exit 1
    fi
done

# Define logs and associated clear commands
declare -A LOG_COMMANDS=(
    ["System Errors (journalctl)"]="journalctl -p 3 -xb"
    ["Kernel Errors (dmesg)"]="dmesg --level=err,warn"
    ["Authentication Errors"]="grep -iE 'error|fail' /var/log/auth.log /var/log/secure 2>/dev/null"
    ["Syslog Errors"]="grep -iE 'error|fail|critical' /var/log/syslog /var/log/messages 2>/dev/null"
    ["Nginx Error Log"]="cat /var/log/nginx/error.log 2>/dev/null"
    ["Apache Error Log"]="cat /var/log/apache2/error.log /var/log/httpd/error_log 2>/dev/null"
)

declare -A CLEAR_COMMANDS=(
    ["System Errors (journalctl)"]="sudo journalctl --rotate && sudo journalctl --vacuum-time=1s"
    ["Kernel Errors (dmesg)"]="sudo dmesg -C"
    ["Authentication Errors"]="sudo truncate -s 0 /var/log/auth.log /var/log/secure 2>/dev/null"
    ["Syslog Errors"]="sudo truncate -s 0 /var/log/syslog /var/log/messages 2>/dev/null"
    ["Nginx Error Log"]="sudo truncate -s 0 /var/log/nginx/error.log"
    ["Apache Error Log"]="sudo truncate -s 0 /var/log/apache2/error.log /var/log/httpd/error_log 2>/dev/null"
)

# Select log interactively with fzf
selected=$(printf '%s\n' "${!LOG_COMMANDS[@]}" | fzf --prompt="Select logs to view: " --height=40% --reverse)

if [[ -z $selected ]]; then
    echo "No selection made. Exiting."
    exit 0
fi

# Execute selected command and view logs
eval "${LOG_COMMANDS[$selected]}" | less -R

# Prompt to clear logs
echo
read -rp "Do you want to clear these logs? [y/N]: " clear_logs

if [[ $clear_logs =~ ^[Yy]$ ]]; then
    read -rp "Are you sure you want to clear logs for '$selected'? [y/N]: " confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
        eval "${CLEAR_COMMANDS[$selected]}"
        echo "✅ Logs cleared for: $selected"
    else
        echo "Aborted clearing logs."
    fi
else
    echo "Logs not cleared."
fi


# Check for necessary dependencies
if ! command -v fzf &> /dev/null; then
    echo "fzf could not be found. Install with 'sudo apt install fzf' or your package manager."
    exit 1
fi

LOG_COMMANDS=(
    "System Errors (journalctl) => journalctl -p 3 -xb"
    "Syslog Errors => grep -iE 'error|fail|critical' /var/log/syslog /var/log/messages 2>/dev/null"
    "Kernel Errors (dmesg) => dmesg --level=err,warn"
    "Authentication Errors => grep -iE 'error|fail' /var/log/auth.log /var/log/secure 2>/dev/null"
    "Nginx Error Log => cat /var/log/nginx/error.log 2>/dev/null"
    "Apache Error Log => cat /var/log/apache2/error.log /var/log/httpd/error_log 2>/dev/null"
)

selected_command=$(printf '%s\n' "${LOG_COMMANDS[@]}" | fzf --prompt="Select logs to view: " --height=40% --reverse)

if [[ -z $selected_command ]]; then
    echo "No selection made. Exiting."
    exit 0
fi

command=$(echo "$selected_command" | awk -F ' => ' '{print $2}')

eval "$command" | less -R

