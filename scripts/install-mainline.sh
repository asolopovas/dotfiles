#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

sudo add-apt-repository -y ppa:cappelikan/ppa
sudo apt-get update -q
sudo apt-get install -y -q mainline
