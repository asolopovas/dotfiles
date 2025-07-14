#!/bin/bash

curl -fsSLO https://github.com/evanphilip/WSL-Hello-sudo/releases/download/v2.1.1/release.tar.gz
tar xvf release.tar.gz
pushd ./release
source install.sh
popd

rm -f release.tar.gz
rm -rf release

