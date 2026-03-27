#!/bin/bash
# Deprecated: use cfg-locale.sh instead
exec "$(dirname "$0")/cfg-locale.sh" "${1:-en_GB.UTF-8}"
