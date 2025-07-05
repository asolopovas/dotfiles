#!/usr/bin/env bash
set -euo pipefail

# ——— Configuration (override if you like) ———
REPO="openai/codex"
TAG="rust-v0.2.0" # full tag on GitHub
# ————————————————————————————————

# Detect CPU
arch="$(uname -m)"
case "$arch" in
x86_64) arch="x86_64" ;;
aarch64) arch="aarch64" ;;
arm64) arch="aarch64" ;; # macOS → arm64
*) echo "✖ unsupported cpu: $arch" && exit 1 ;;
esac

# Detect OS / C library / archive type
case "$(uname -s)" in
Linux)
    if ldd --version 2>&1 | grep -q musl; then
        os="unknown-linux-musl"
    else
        os="unknown-linux-gnu"
    fi
    ext="tar.gz"
    ;;
Darwin)
    os="apple-darwin"
    ext="tar.gz"
    ;;
MINGW* | MSYS* | CYGWIN*)
    os="pc-windows-msvc"
    ext="zip"
    ;;
*) echo "✖ unsupported os: $(uname -s)" && exit 1 ;;
esac

asset="codex-${arch}-${os}.${ext}"
url="https://github.com/${REPO}/releases/download/${TAG}/${asset}"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"

echo "➜ downloading $asset …"
curl -L# "$url" -o "$asset"

echo "➜ unpacking …"
if [[ $ext == zip ]]; then
    unzip -q "$asset" codex.exe
    cp codex.exe "$OLDPWD"
    echo "✔ codex.exe ready → $(cygpath -w "$OLDPWD")"
else
    tar -xzf "$asset" codex
    sudo install -m755 codex /usr/local/bin/
    echo "✔ codex installed to /usr/local/bin (try: codex --help)"
fi
