#!/bin/bash

VERSION="0.4.5"
DEST="$HOME/.local/bin"
ARCHITECHTURE="linux-amd64"
URL="https://github.com/docker/hub-tool/releases/download/v$VERSION/hub-tool-linux-amd64.tar.gz"

curl -#fsSL "$URL" -o $HOME/tmp/hub-tool.tar.gz
tar -xf $HOME/tmp/hub-tool.tar.gz && mv hub-tool/hub-tool $DEST && rm -r hub-tool
chmod +x $DEST/hub-tool
