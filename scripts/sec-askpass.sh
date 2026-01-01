#!/bin/bash

# Disable echo and set up trap to restore echo on script exit
stty -echo
trap 'stty echo' EXIT

# Prompt for the password
echo -n "Password: " >&2
password=""
visible_password=""

# Read input character by character
while IFS= read -r -s -n1 char; do
    # Check for end of input (Enter key)
    if [[ $char == $'\0' ]]; then
        break
    fi

    # Check for backspace character
    if [[ $char == $'\177' ]]; then
        if [ ${#password} -gt 0 ]; then
            password="${password%?}"
            visible_password="${visible_password%?}"
            # Move cursor back, print space to clear the last *, and move cursor back again
            echo -ne "\b \b" >&2
        fi
    else
        # Append character to password and visible password
        password+="$char"
        visible_password+="*"
        # Print * to show the password length
        echo -n "*" >&2
    fi
done

# Restore echo
stty echo
trap - EXIT

echo "$password"
