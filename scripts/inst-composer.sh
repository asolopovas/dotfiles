#!/bin/bash

INSTALL_PATH="$HOME/.local/bin/composer"

if [ "$FORCE" = true ]; then
    rm -f "$INSTALL_PATH"
fi

if [ ! -f "$INSTALL_PATH" ]; then
    echo "Installing Composer..."
    mkdir -p "$(dirname "$INSTALL_PATH")"
    curl -sS https://getcomposer.org/download/latest-stable/composer.phar -o "$INSTALL_PATH"
    chmod +x "$INSTALL_PATH"
    echo "Composer installed successfully at $INSTALL_PATH."
else
    echo "Composer is already installed at $INSTALL_PATH."
fi
