#!/bin/bash
set -euo pipefail
exec "$(dirname "$0")/wsl-windows-hello.sh" "$@"
