#!/bin/bash

dnf install -y gcc make ncurses-devel
BASH_VERSION="5.2.15"
curl -O http://ftp.gnu.org/gnu/bash/bash-$BASH_VERSION.tar.gz
tar xvf bash-$BASH_VERSION.tar.gz && cd bash-$BASH_VERSION
./configure --prefix=/usr && make && make install
bash --version
read -p "Default shell? (y/N): " choice
[[ $choice == y || $choice == Y ]] && chsh -s /usr/bin/bash
cd .. && rm -rf bash-$BASH_VERSION.tar.gz bash-$BASH_VERSION
