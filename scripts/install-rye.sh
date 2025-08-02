#!/bin/bash

set -euo pipefail

RYE_HOME="${HOME}/.rye"
SHIMS_PATH="${RYE_HOME}/shims"

if command -v rye &> /dev/null; then
    echo "Rye is already installed. Version: $(rye --version)"
    echo "To update, run: rye self update"
else
    echo "Installing Rye..."
    export RYE_INSTALL_OPTION="--yes"
    curl -sSf https://rye.astral.sh/get | bash
fi
