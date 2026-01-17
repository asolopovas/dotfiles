#!/usr/bin/env bash
set -euo pipefail

LOCALE="en_GB.UTF-8"

echo "Installing locales package..."
sudo apt-get update -y
sudo apt-get install -y locales

echo "Ensuring $LOCALE is generated..."
sudo sed -i "s/^# *${LOCALE}/${LOCALE}/" /etc/locale.gen || true
sudo locale-gen "$LOCALE"

echo "Setting default locale..."
sudo update-locale LANG="$LOCALE" LANGUAGE="$LOCALE"

echo "Current locale:"
locale
