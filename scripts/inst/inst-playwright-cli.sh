#!/bin/bash
set -euo pipefail

source "$HOME/dotfiles/globals.sh"

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

if [[ -d /opt/plesk ]]; then
    if [[ ! -d /opt/plesk/node ]]; then
        print_color red "Plesk Node directory is unavailable: /opt/plesk/node"
        exit 1
    fi
    PLESK_NODE_VERSION=$(find /opt/plesk/node -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -V | tail -1)
    if [[ -z "$PLESK_NODE_VERSION" ]]; then
        print_color red "No Plesk Node versions are installed under /opt/plesk/node"
        exit 1
    fi
    NPM_PREFIX="/opt/plesk/node/$PLESK_NODE_VERSION"
    NPM_BIN="$NPM_PREFIX/bin/npm"
    if [[ ! -x "$NPM_BIN" ]]; then
        print_color red "Latest Plesk Node npm is unavailable: $NPM_BIN"
        exit 1
    fi
    export PATH="$NPM_PREFIX/bin:$PATH"
else
    require_cmd npm scripts/inst/inst-node.sh || exit 1
    NPM_BIN=$(command -v npm)
    VOLTA_HOME="${VOLTA_HOME:-$HOME/.volta}"
    if cmd_exist volta && [[ "$NPM_BIN" == "$VOLTA_HOME/bin/npm" ]]; then
        volta uninstall @playwright/cli >/dev/null 2>&1 || true
        NPM_BIN=$(volta which npm)
    fi
    NPM_PREFIX=$("$NPM_BIN" prefix -g)
fi

PLAYWRIGHT_CLI_VERSION=$("$NPM_BIN" view @playwright/cli@latest version)
PLAYWRIGHT_PACKAGE_BIN="$NPM_PREFIX/bin/playwright-cli"
INSTALLED_PLAYWRIGHT_CLI_VERSION=""
if [[ -x "$PLAYWRIGHT_PACKAGE_BIN" ]]; then
    INSTALLED_PLAYWRIGHT_CLI_VERSION=$(PATH="$(dirname "$NPM_BIN"):$PATH" "$PLAYWRIGHT_PACKAGE_BIN" --version 2>/dev/null || true)
fi

if [[ ${FORCE:-false} == true ]] || [[ "$INSTALLED_PLAYWRIGHT_CLI_VERSION" != "$PLAYWRIGHT_CLI_VERSION" ]]; then
    print_color green "Installing Playwright CLI $PLAYWRIGHT_CLI_VERSION..."
    "$NPM_BIN" install -g --prefix "$NPM_PREFIX" "@playwright/cli@$PLAYWRIGHT_CLI_VERSION"
else
    print_color green "Playwright CLI $PLAYWRIGHT_CLI_VERSION is already installed."
fi

if [[ ! -x "$PLAYWRIGHT_PACKAGE_BIN" ]]; then
    print_color red "playwright-cli was not found after installation: $PLAYWRIGHT_PACKAGE_BIN"
    exit 1
fi

PLAYWRIGHT_CLI_BIN="$PLAYWRIGHT_PACKAGE_BIN"
if [[ -d /opt/plesk ]]; then
    cat >/usr/local/bin/playwright-cli <<WRAPPER
#!/bin/bash
export PATH="$(dirname "$NPM_BIN"):\$PATH"
export PLAYWRIGHT_BROWSERS_PATH="$PLAYWRIGHT_BROWSERS_PATH"
exec "$PLAYWRIGHT_PACKAGE_BIN" "\$@"
WRAPPER
    chmod 755 /usr/local/bin/playwright-cli
    PLAYWRIGHT_CLI_BIN=/usr/local/bin/playwright-cli

    cat >/usr/local/bin/playwright <<'WRAPPER'
#!/bin/sh
printf '%s\n' 'playwright: legacy wrapper disabled; use playwright-cli, or npx --no-install playwright test for project-owned tests.' >&2
exit 127
WRAPPER
    chmod 755 /usr/local/bin/playwright
fi

print_color green "Installing Playwright CLI Chromium with system dependencies..."
"$PLAYWRIGHT_CLI_BIN" install-browser chromium --with-deps

if [[ -d /opt/plesk ]]; then
    chmod -R a+rX "$PLAYWRIGHT_BROWSERS_PATH"
fi

print_color green "Smoke-testing Playwright CLI Chromium..."
"$PLAYWRIGHT_CLI_BIN" open --browser=chromium about:blank
"$PLAYWRIGHT_CLI_BIN" close

print_color green "Playwright CLI $("$PLAYWRIGHT_CLI_BIN" --version) installation complete."
