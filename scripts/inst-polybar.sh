#!/bin/bash
set -euo pipefail
source "$HOME/dotfiles/globals.sh"

POLYBAR_VERSION="${1:-$(gh_latest_release polybar/polybar)}"
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

print_color green "Installing polybar ${POLYBAR_VERSION} from source"

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

cd "$BUILD_DIR"
curl -fsSL "https://github.com/polybar/polybar/releases/download/${POLYBAR_VERSION}/polybar-${POLYBAR_VERSION}.tar.gz" | tar xz
cd "polybar-${POLYBAR_VERSION}"

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
sudo make install

print_color green "Done: $(polybar --version | head -1)"
