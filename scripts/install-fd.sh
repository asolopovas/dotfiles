#!/bin/bash

if [ "$OS" = "ubuntu" ] || [ ""$OS"" = "debian" ]; then
    print_color green "INSTALLING FD-FIND..."
    curl -fsSLO https://github.com/sharkdp/fd/releases/download/v8.5.3/fd-musl_8.5.3_amd64.deb
    sudo dpkg -i fd-musl_8.5.3_amd64.deb
    rm -rf fd-musl_8.5.3_amd64.deb
fi

if [ "$OS" = "alpine" ]; then
    $PI i fd
fi
