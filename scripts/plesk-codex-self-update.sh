#!/bin/bash
set -euo pipefail

if [[ $# -ne 0 ]]; then
    echo "Usage: codex-self-update" >&2
    exit 2
fi

exec /opt/dotfiles/scripts/plesk-init.sh codex-update
