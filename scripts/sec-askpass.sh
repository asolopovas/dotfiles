#!/bin/bash

stty -echo
trap 'stty echo' EXIT

echo -n "Password: " >&2
password=""
visible_password=""

while IFS= read -r -s -n1 char; do
    if [[ $char == $'\0' ]]; then
        break
    fi

    if [[ $char == $'\177' ]]; then
        if [ ${#password} -gt 0 ]; then
            password="${password%?}"
            visible_password="${visible_password%?}"
            echo -ne "\b \b" >&2
        fi
    else
        password+="$char"
        visible_password+="*"
        echo -n "*" >&2
    fi
done

stty echo
trap - EXIT

echo "$password"
