#!/usr/bin/env bash
set -euo pipefail

RYE_HOME="${HOME}/.rye"

if command -v rye &> /dev/null; then
  echo "Rye is already installed. Version: $(rye --version)"
  echo "To update, run: rye self update"
else
  echo "Installing Rye..."
  export RYE_INSTALL_OPTION="--yes"
  export RYE_TOOLCHAIN_VERSION="3.11"
  curl -sSf https://rye.astral.sh/get | bash
  echo "→ Remember to source ‘\$HOME/.rye/env’ in your shell to enable shims"
fi

echo "Configuring Rye global behavior..."
rye config --set-bool behavior.global-python=true
rye config --set-bool behavior.use-uv=true

PYTHON_PIN="3.11"

echo "Pinning Python $PYTHON_PIN to project and globally..."
rye pin --relaxed "${PYTHON_PIN}"
# Optionally add specific version detail: rye pin @3.11.11
echo "Fetching Python toolchain (if not already installed)..."
rye toolchain fetch "${PYTHON_PIN}"
echo "Confirmed installed toolchains:"
rye toolchain list

echo "Rye setup complete. To verify, try:"
echo "  python --version"
echo "  rye run python --version"
