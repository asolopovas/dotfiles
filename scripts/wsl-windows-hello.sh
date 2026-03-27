#!/bin/bash
set -euo pipefail

VER="v2.1.1"
URL="https://github.com/evanphilip/WSL-Hello-sudo/releases/download/$VER/release.tar.gz"
TMP=$(mktemp -d)

curl -fsSL "$URL" -o "$TMP/release.tar.gz"
tar xzf "$TMP/release.tar.gz" -C "$TMP"
source "$TMP/release/install.sh"
rm -rf "$TMP"
