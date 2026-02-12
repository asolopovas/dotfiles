#!/bin/bash
set -euo pipefail

source "$HOME/dotfiles/globals.sh"

if ! command -v npm >/dev/null 2>&1; then
    print_color red "npm is required. Install Node.js first (scripts/inst-node.sh)."
    exit 1
fi

print_color green "Installing Playwright CLI..."
npm install -g @playwright/cli@latest

if ! command -v playwright-cli >/dev/null 2>&1; then
    print_color red "playwright-cli was not found after installation."
    exit 1
fi

print_color green "Installing Playwright CLI skills..."
playwright-cli install --skills

print_color green "Playwright CLI installation complete."
