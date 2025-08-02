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

echo "Configuring Rye for global Python usage..."
rye config --set-bool behavior.global-python=true
rye config --set-bool behavior.use-uv=true

echo "Installing Python 3.11 and setting as global..."
rye install python@3.11
rye pin python@3.11

echo "Rye configuration complete. Global Python access enabled."
