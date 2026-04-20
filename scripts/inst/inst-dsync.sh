#!/bin/bash
set -euo pipefail
source "$HOME/dotfiles/globals.sh"

require_cmd go scripts/inst/inst-golang.sh || exit 1

print_color green "Installing dsync@latest..."
go install github.com/asolopovas/dsync@latest
