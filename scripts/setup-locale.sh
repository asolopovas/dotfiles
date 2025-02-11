#!/bin/bash

setup_locale() {
    LOCALE=${1:-en_GB.UTF-8}
    locale | grep -q "$LOCALE" && echo "$LOCALE already set." && return 0
    sudo sed -i "/^# $LOCALE UTF-8/s/^# //" /etc/locale.gen
    sudo locale-gen
    sudo update-locale LC_ALL=$LOCALE LANG=$LOCALE LANGUAGE=$LOCALE
    echo -e "LANG=$LOCALE\nLANGUAGE=$LOCALE\nLC_ALL=$LOCALE" | sudo tee /etc/default/locale > /dev/null
    echo "$LOCALE setup complete!"
}

setup_locale "$1"
