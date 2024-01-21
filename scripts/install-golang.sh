#!/bin/bash

VER="1.21.6"
ARCH="linux-amd64"
LOC="/usr/local"

rm -rf $LOC/go

curl -#LO "https://golang.org/dl/go${VER}.${ARCH}.tar.gz"
sudo tar -xzf "go${VER}.${ARCH}.tar.gz" -C $LOC
rm "go${VER}.${ARCH}.tar.gz"

