#!/bin/bash
set -euo pipefail
source "$HOME/dotfiles/globals.sh"

if ! cmd_exist go; then
    print_color red "Go is required (scripts/inst-golang.sh)"
    exit 1
fi

print_color green "Installing dsync@latest..."
go install github.com/asolopovas/dsync@latest
