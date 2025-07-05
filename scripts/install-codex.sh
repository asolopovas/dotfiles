#!/usr/bin/env bash
set -euo pipefail

# OpenAI Codex CLI installer
# Downloads and installs the latest Codex CLI binary

# Configuration
REPO="openai/codex"
TAG="rust-v0.2.0"

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

# Construct download URL
asset="codex-${arch}-${os}.tar.gz"
url="https://github.com/${REPO}/releases/download/${TAG}/${asset}"

echo "Installing Codex CLI..."
echo "Architecture: $arch"
echo "OS: $os"
echo "Asset: $asset"
echo

# Create temporary directory
tmp=$(mktemp -d)
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
if ! tar -xzf "$asset" codex; then
    echo "✖ Failed to extract binary"
    exit 1
fi

# Install binary
echo "➜ Installing to /usr/local/bin..."
if ! sudo install -m755 codex /usr/local/bin/; then
    echo "✖ Failed to install binary"
    exit 1
fi

echo "✔ Codex CLI installed successfully!"
echo "  Try: codex --help"
