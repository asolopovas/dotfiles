#!/bin/bash

source $HOME/dotfiles/globals.sh

VER="7.2.0"
curl fsSLO https://github.com/redis/redis/archive/$VER.tar.gz
tar -xf $VER.tar.gz

