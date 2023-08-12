#!/bin/bash

OS=$(awk '/^ID=/' /etc/os-release | sed -e 's/ID=//' -e 's/"//g' | tr '[:upper:]' '[:lower:]')

if [ $OS = 'ubuntu' ]; then
    sudo snap install go --classic
fi
