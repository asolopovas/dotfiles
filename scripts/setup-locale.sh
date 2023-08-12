#!/bin/bash

setup_locale() {
    LOCALE=${1:-en_US.UTF-8}
    sudo sed -i "s/# $LOCALE UTF-8/$LOCALE UTF-8/" /etc/locale.gen
    sudo locale-gen $LOCALE
    sudo update-locale LC_ALL=$LOCALE LANG=$LOCALE
    source ~/.bashrc
    echo "$LOCALE setup complete!"
}

setup_locale $1
