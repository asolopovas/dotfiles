#!/bin/bash
set -euo pipefail

curl -fsSLO https://raw.githubusercontent.com/pimlie/ubuntu-mainline-kernel.sh/master/ubuntu-mainline-kernel.sh
sudo install ubuntu-mainline-kernel.sh /usr/local/bin/
rm -f ubuntu-mainline-kernel.sh
