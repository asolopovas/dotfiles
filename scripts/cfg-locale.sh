#!/bin/bash

setup_locale() {
    LOCALE=${1:-en_GB.UTF-8}

    # Check if locale is already set
    if locale -a | grep -qi "^${LOCALE}$"; then
        echo "$LOCALE already set."
        return 0
    fi

    echo "Setting up locale: $LOCALE"

    # Ensure the locale exists in locale.gen
    if ! grep -q "^$LOCALE UTF-8" /etc/locale.gen; then
        sudo sed -i "/^# $LOCALE UTF-8/s/^# //" /etc/locale.gen
    fi

    # Generate locales
    sudo locale-gen
    sudo update-locale LANG=$LOCALE LANGUAGE=$LOCALE

    # Ensure the locale settings are applied system-wide
    echo -e "LANG=$LOCALE\nLANGUAGE=$LOCALE" | sudo tee /etc/default/locale > /dev/null

    echo "$LOCALE setup complete!"
}

setup_locale "$1"
