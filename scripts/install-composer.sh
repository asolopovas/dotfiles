#!/bin/bash

COMPOSER_VERSION=2.6.5
INSTALL_PATH="$HOME/.local/bin/composer"
mkdir -p $(dirname $INSTALL_PATH)
curl -sS https://getcomposer.org/download/$COMPOSER_VERSION/composer.phar -o $INSTALL_PATH
chmod +x $INSTALL_PATH
$INSTALL_PATH --version
