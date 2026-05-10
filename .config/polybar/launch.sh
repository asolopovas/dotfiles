#!/usr/bin/env bash

if [[ -t 0 || -t 1 || -t 2 ]] && [[ -z $POLYBAR_DETACHED ]]; then
    POLYBAR_DETACHED=1 setsid -f "$0" "$@" </dev/null >/dev/null 2>&1
    exit 0
fi

CONFIG_DIR=$HOME/dotfiles/.config/polybar
THEME=minimal
CONFIG=$CONFIG_DIR/themes/$THEME/config.ini

killall polybar >/dev/null 2>&1
while pgrep -u "$UID" -x polybar >/dev/null; do sleep 1; done

net_interface=$(ip route show | awk '/^default/ {print $5}')
export net_interface

primary=""
others=()
while read -r line; do
    [[ -z $line ]] && continue
    name="${line%%:*}"
    if [[ $line == *"(primary)"* ]]; then
        primary="$name"
    else
        others+=("$name")
    fi
done < <(polybar --list-monitors 2>/dev/null)

if [[ -z $primary && ${#others[@]} -gt 0 ]]; then
    primary="${others[0]}"
    others=("${others[@]:1}")
fi

if [[ -z $primary ]]; then
    CONFIG_DIR=$CONFIG_DIR SCREEN_LABEL=1 \
        polybar main -c "$CONFIG" --reload >>/tmp/polybar-main.log 2>&1 &
    wait
    exit 0
fi

label=1
CONFIG_DIR=$CONFIG_DIR MONITOR="$primary" SCREEN_LABEL=$label \
    polybar main -c "$CONFIG" --reload >>/tmp/polybar-main.log 2>&1 &
((label++))
sleep 1

if [[ ${#others[@]} -eq 0 ]]; then
    wait
    exit 0
fi

for mon in "${others[@]}"; do
    CONFIG_DIR=$CONFIG_DIR MONITOR="$mon" SCREEN_LABEL=$label \
        polybar secondary -c "$CONFIG" --reload >>/tmp/polybar-secondary-$label.log 2>&1 &
    ((label++))
    sleep 1
done

wait
