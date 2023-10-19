#!/bin/bash

VER="1.14.3"
ARCH="linux-amd64"

rm -rf /usr/local/go

curl -#LO "https://golang.org/dl/go${VER}.${ARCH}.tar.gz"
sudo tar -C /usr/local -xzf "go${VER}.${ARCH}.tar.gz"
rm "go${VER}.${ARCH}.tar.gz"

