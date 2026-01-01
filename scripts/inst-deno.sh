#!/bin/bash

curl -fsSL https://deno.land/install.sh | sh -s -- -y --no-modify-path

if [ -d "$HOME/.deno/bin" ]; then
    export PATH="$HOME/.deno/bin:$PATH"
fi
