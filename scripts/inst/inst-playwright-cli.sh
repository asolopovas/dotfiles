#!/bin/bash
set -euo pipefail

source "$HOME/dotfiles/globals.sh"

require_cmd npm scripts/inst/inst-node.sh || exit 1

# On the Plesk server browsers are shared from /opt/playwright-browsers and the
# global npm root is under /opt/plesk/node — both root-only. Vhost users must
# never run this; a broken playwright-cli on a vhost is an admin problem.
if [[ -d /opt/plesk ]] && [[ $EUID -ne 0 ]]; then
    print_color red "This installer must run as root on the server."
    print_color red "Vhost users cannot provision playwright-cli — report the problem to the server admin instead."
    exit 1
fi

if [[ -d /opt/plesk ]]; then
    export PLAYWRIGHT_BROWSERS_PATH=/opt/playwright-browsers
    if ! grep -q '^PLAYWRIGHT_BROWSERS_PATH=' /etc/environment; then
        echo "PLAYWRIGHT_BROWSERS_PATH=$PLAYWRIGHT_BROWSERS_PATH" >>/etc/environment
        print_color green "Added PLAYWRIGHT_BROWSERS_PATH to /etc/environment"
    fi
fi

print_color green "Installing Playwright CLI..."
npm install -g @playwright/cli@latest

if ! command -v playwright-cli >/dev/null 2>&1; then
    print_color red "playwright-cli was not found after installation."
    exit 1
fi

print_color green "Installing Playwright CLI skills..."
playwright-cli install --skills

print_color green "Installing Chromium with system dependencies..."
playwright-cli install-browser chromium --with-deps

if [[ -d /opt/plesk ]]; then
    # Vhost users run browsers from the shared path; make it world-readable.
    chmod -R a+rX "$PLAYWRIGHT_BROWSERS_PATH"
fi

print_color green "Playwright CLI $(playwright-cli --version) installation complete."
