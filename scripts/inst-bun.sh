#!/bin/bash

if [ "${FORCE:-false}" != true ] && command -v bun &>/dev/null; then
    echo "bun $(bun --version) already installed — skipping"
    return 0 2>/dev/null || exit 0
fi

curl -fsSL https://bun.com/install | bash
