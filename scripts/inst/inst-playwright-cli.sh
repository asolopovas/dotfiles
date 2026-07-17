#!/bin/bash
set -euo pipefail

source "$HOME/dotfiles/globals.sh"

require_cmd npm scripts/inst/inst-node.sh || exit 1

if [[ -d /opt/plesk ]] && [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    print_color red "This installer must run as root on the server."
    print_color red "Vhost users cannot provision playwright-cli — report the problem to the server admin instead."
    exit 1
fi

if [[ -d /opt/plesk ]]; then
    export PLAYWRIGHT_BROWSERS_PATH=/opt/playwright-browsers
    if ! grep -q '^PLAYWRIGHT_BROWSERS_PATH=' /etc/environment; then
        printf 'PLAYWRIGHT_BROWSERS_PATH=%s\n' "$PLAYWRIGHT_BROWSERS_PATH" >>/etc/environment
        print_color green "Added PLAYWRIGHT_BROWSERS_PATH to /etc/environment"
    fi
fi

NPM_BIN=$(command -v npm)
VOLTA_HOME="${VOLTA_HOME:-$HOME/.volta}"
if cmd_exist volta && [[ "$NPM_BIN" == "$VOLTA_HOME/bin/npm" ]]; then
    volta uninstall @playwright/cli >/dev/null 2>&1 || true
    NPM_BIN=$(volta which npm)
fi

PLAYWRIGHT_CLI_VERSION=$("$NPM_BIN" view @playwright/cli@latest version)
PLAYWRIGHT_VERSION="${PLAYWRIGHT_VERSION:-$("$NPM_BIN" view playwright@latest version)}"
INSTALLED_PLAYWRIGHT_CLI_VERSION=""
if cmd_exist playwright-cli; then
    INSTALLED_PLAYWRIGHT_CLI_VERSION=$(playwright-cli --version)
fi

if [[ ${FORCE:-false} == true ]] || [[ "$INSTALLED_PLAYWRIGHT_CLI_VERSION" != "$PLAYWRIGHT_CLI_VERSION" ]]; then
    print_color green "Installing Playwright CLI $PLAYWRIGHT_CLI_VERSION..."
    "$NPM_BIN" install -g "@playwright/cli@$PLAYWRIGHT_CLI_VERSION"
else
    print_color green "Playwright CLI $PLAYWRIGHT_CLI_VERSION is already installed."
fi

NPM_PREFIX=$("$NPM_BIN" prefix -g)
export PATH="$NPM_PREFIX/bin:$PATH"
hash -r

if ! command -v playwright-cli >/dev/null 2>&1; then
    print_color red "playwright-cli was not found after installation."
    exit 1
fi

print_color green "Installing Playwright CLI Chromium with system dependencies..."
playwright-cli install-browser chromium --with-deps

print_color green "Installing Playwright $PLAYWRIGHT_VERSION stable Chromium with system dependencies..."
"$NPM_BIN" exec --yes --package="playwright@$PLAYWRIGHT_VERSION" -- playwright install chromium --with-deps

if [[ -d /opt/plesk ]]; then
    chmod -R a+rX "$PLAYWRIGHT_BROWSERS_PATH"
fi

print_color green "Playwright CLI $(playwright-cli --version) and Playwright $PLAYWRIGHT_VERSION stable installation complete."
