#!/bin/bash
set -euo pipefail

POLYBAR_VERSION="${1:-3.7.2}"
BUILD_DIR="/tmp/polybar-build"

echo "==> Installing polybar $POLYBAR_VERSION from source"

# Install build dependencies
sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends \
    build-essential cmake cmake-data pkg-config \
    libasound2-dev libcurl4-openssl-dev libjsoncpp-dev \
    libmpdclient-dev libnl-genl-3-dev libpulse-dev \
    libxcb-composite0-dev libxcb-cursor-dev libxcb-ewmh-dev \
    libxcb-icccm4-dev libxcb-image0-dev libxcb-randr0-dev \
    libxcb-util0-dev libxcb-xkb-dev libxcb-xrm-dev libxcb1-dev \
    python3-sphinx python3-packaging libuv1-dev \
    xcb-proto python3-xcbgen

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Download and extract
echo "==> Downloading polybar $POLYBAR_VERSION"
curl -sL "https://github.com/polybar/polybar/releases/download/${POLYBAR_VERSION}/polybar-${POLYBAR_VERSION}.tar.gz" | tar xz
cd "polybar-${POLYBAR_VERSION}"

# Build
echo "==> Building"
mkdir build && cd build
cmake .. \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DENABLE_ALSA=ON \
    -DENABLE_CURL=ON \
    -DENABLE_I3=OFF \
    -DENABLE_MPD=ON \
    -DENABLE_NETWORK=ON \
    -DENABLE_PULSEAUDIO=ON \
    -DBUILD_DOC=OFF
make -j"$(nproc)"

# Install
echo "==> Installing"
sudo make install

# Clean up
rm -rf "$BUILD_DIR"

echo "==> Done: $(polybar --version)"
