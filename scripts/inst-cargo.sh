#!/bin/bash

if [ "${FORCE:-false}" != true ] && command -v cargo &>/dev/null; then
    echo "cargo already installed — skipping"
    return 0 2>/dev/null || exit 0
fi

curl https://sh.rustup.rs -sSf | sh
