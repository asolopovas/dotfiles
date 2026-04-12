#!/bin/bash

if [ "${FORCE:-false}" != true ] && command -v deno &>/dev/null; then
    echo "deno $(deno --version | head -1) already installed — skipping"
    return 0 2>/dev/null || exit 0
fi

curl -fsSL https://deno.land/install.sh | sh -s -- -y --no-modify-path

if [ -d "$HOME/.deno/bin" ]; then
    export PATH="$HOME/.deno/bin:$PATH"
fi
