#!/bin/bash

set -euo pipefail

RYE_HOME="${HOME}/.rye"
SHIMS_PATH="${RYE_HOME}/shims"

echo "Installing Rye Python management tool..."
echo ""
echo "NOTE: As of 2025, UV is the recommended successor to Rye from the same maintainers."
echo "Consider using UV instead: https://github.com/astral-sh/uv"
echo "Continuing with Rye installation..."
echo ""

if command -v rye &> /dev/null; then
    echo "Rye is already installed. Version: $(rye --version)"
    echo "To update, run: rye self update"
else
    echo "Installing Rye..."
    export RYE_INSTALL_OPTION="--yes"
    curl -sSf https://rye.astral.sh/get | bash
fi

echo "Configuring Rye..."
if [ -f "${RYE_HOME}/env" ]; then
    source "${RYE_HOME}/env"
fi

export PATH="${SHIMS_PATH}:${PATH}"

echo "Setting up global Python toolchain..."
rye config --set default.toolchain=cpython@3.12.9

echo "Installing essential global tools..."
rye install pip

echo "Setting up shell completion..."
if [ -n "${BASH_VERSION:-}" ]; then
    mkdir -p ~/.local/share/bash-completion/completions
    rye self completion > ~/.local/share/bash-completion/completions/rye.bash 2>/dev/null || true
fi

echo "Verifying installation..."
echo "Rye version: $(rye --version)"

echo "Testing Python toolchain..."
if command -v python &> /dev/null; then
    echo "Python version: $(python --version)"
else
    echo "Warning: Python not found in PATH. Installing default toolchain..."
    rye install cpython@3.12.9
fi

if command -v pip &> /dev/null; then
    echo "Pip version: $(pip --version)"
else
    echo "Warning: Pip not accessible through shims"
fi

echo "Testing project creation..."
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"
rye init test-project --no-readme --no-pin &> /dev/null || echo "Warning: Project creation test failed"
cd - > /dev/null
rm -rf "$TEMP_DIR"

echo ""
echo "Rye installation completed!"
echo ""
echo "Configuration summary:"
echo "- Default toolchain: cpython@3.12.9"
echo "- Global tools: pip"
echo "- Shims path: ${SHIMS_PATH}"
echo "- Shell completion: enabled for bash"
echo ""
echo "Important notes:"
echo "- Rye manages Python versions automatically"
echo "- Use 'rye install <package>' for global tools"
echo "- Use 'rye add <package>' in projects for dependencies"
echo "- Virtual environments don't include pip by design"
echo ""
echo "Next steps:"
echo "- Restart your shell or run: source ~/.rye/env"
echo "- Consider migrating to UV: https://github.com/astral-sh/uv"