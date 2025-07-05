#!/usr/bin/env bash
set -euo pipefail

# OpenAI Codex CLI installer
# Downloads and installs the latest Codex CLI binary
# Usage: install-codex.sh [--root]
#   --root: Install to /usr/local/bin (requires sudo)
#   default: Install to ~/.local/bin

# Configuration
REPO="openai/codex"
TAG="rust-v0.2.0"

# Parse arguments
USE_ROOT=false
for arg in "$@"; do
    case $arg in
        --root)
            USE_ROOT=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--root]"
            echo "  --root: Install to /usr/local/bin (requires sudo)"
            echo "  default: Install to ~/.local/bin"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Detect CPU architecture
arch="$(uname -m)"
case "$arch" in
    x86_64) arch="x86_64" ;;
    aarch64) arch="aarch64" ;;
    arm64) arch="aarch64" ;;  # macOS arm64
    *) echo "✖ Unsupported CPU architecture: $arch" && exit 1 ;;
esac

# Detect OS and C library
case "$(uname -s)" in
    Linux)
        if ldd --version 2>&1 | grep -q musl; then
            os="unknown-linux-musl"
        else
            os="unknown-linux-gnu"
        fi
        ;;
    Darwin)
        os="apple-darwin"
        ;;
    MINGW* | MSYS* | CYGWIN*)
        echo "✖ Windows is not supported. Use WSL or Linux instead."
        exit 1
        ;;
    *) 
        echo "✖ Unsupported OS: $(uname -s)"
        exit 1
        ;;
esac

# Set install directory
if [[ "$USE_ROOT" == "true" ]]; then
    INSTALL_DIR="/usr/local/bin"
    INSTALL_CMD="sudo install"
else
    INSTALL_DIR="$HOME/.local/bin"
    INSTALL_CMD="install"
    # Ensure ~/.local/bin exists
    mkdir -p "$HOME/.local/bin"
fi

# Construct download URL
asset="codex-${arch}-${os}.tar.gz"
url="https://github.com/${REPO}/releases/download/${TAG}/${asset}"

echo "Installing Codex CLI..."
echo "Architecture: $arch"
echo "OS: $os"
echo "Asset: $asset"
echo "Install directory: $INSTALL_DIR"
echo

# Create temporary directory for testing or use /tmp/install-codex/
if [[ "${TMPDIR:-}" == "/tmp/install-codex/" ]] || [[ "${PWD}" == "/tmp/install-codex"* ]]; then
    tmp="/tmp/install-codex/download"
    mkdir -p "$tmp"
else
    tmp=$(mktemp -d)
fi

# Ensure cleanup on exit
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"

# Download binary
echo "➜ Downloading $asset..."
if ! curl -L# "$url" -o "$asset"; then
    echo "✖ Failed to download $asset"
    exit 1
fi

# Extract binary
echo "➜ Extracting binary..."
binary_name="codex-${arch}-${os}"
if ! tar -xzf "$asset" "$binary_name"; then
    echo "✖ Failed to extract binary"
    exit 1
fi

# Install binary
echo "➜ Installing to $INSTALL_DIR..."
if ! $INSTALL_CMD -m755 "$binary_name" "$INSTALL_DIR/codex"; then
    echo "✖ Failed to install binary to $INSTALL_DIR"
    exit 1
fi

echo "✔ Codex CLI installed successfully!"
echo "  Location: $INSTALL_DIR/codex"
echo "  Try: codex --help"

# Check if ~/.local/bin is in PATH
if [[ "$USE_ROOT" == "false" ]] && [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo
    echo "⚠ Warning: $HOME/.local/bin is not in your PATH"
    echo "  Add this to your shell profile (.bashrc, .zshrc, etc.):"
    echo "  export PATH=\"$HOME/.local/bin:\$PATH\""
fi
