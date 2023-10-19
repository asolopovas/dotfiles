#!/bin/sh

# Ensure the target directory exists
mkdir -p "$HOME/src"

# Change to the target directory
cd "$HOME/src" || exit 1

# Variables
VER="451.0.0"
ARCH="x86_64"
NAME="google-cloud-cli-${VER}-linux-${ARCH}.tar.gz"

# Method 3: Install using a .tar.gz file
curl -#fsSLO "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/$NAME"
tar zxvf "$NAME"
./google-cloud-sdk/install.sh
rm -rf "$NAME"
