#!/bin/bash

source $HOME/dotfiles/globals.sh

sudo add-apt-repository -y ppa:hvr/ghc
sudo apt-get update -y && sudo apt upgrade -y

installPackages build-essential libgmp-dev oftware-properties-common ghc
