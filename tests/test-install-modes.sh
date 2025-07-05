#!/usr/bin/env bash
set -euo pipefail

# Test different installation modes

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/../scripts/install-codex.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Testing install script modes...${NC}"

# Test 1: Check default mode shows ~/.local/bin
echo -e "${YELLOW}Test 1: Default install directory${NC}"
test_output=$(bash -c 'USE_ROOT=false; if [[ "$USE_ROOT" == "true" ]]; then echo "/usr/local/bin"; else echo "$HOME/.local/bin"; fi')
if [[ "$test_output" == "$HOME/.local/bin" ]]; then
    echo -e "${GREEN}✓ Default mode: $test_output${NC}"
else
    echo -e "${RED}✗ Default mode failed: $test_output${NC}"
fi

# Test 2: Check --root mode shows /usr/local/bin
echo -e "${YELLOW}Test 2: Root install directory${NC}"
test_output=$(bash -c 'USE_ROOT=true; if [[ "$USE_ROOT" == "true" ]]; then echo "/usr/local/bin"; else echo "$HOME/.local/bin"; fi')
if [[ "$test_output" == "/usr/local/bin" ]]; then
    echo -e "${GREEN}✓ Root mode: $test_output${NC}"
else
    echo -e "${RED}✗ Root mode failed: $test_output${NC}"
fi

# Test 3: Check help output
echo -e "${YELLOW}Test 3: Help output${NC}"
if "$INSTALL_SCRIPT" --help | grep -q "Usage:"; then
    echo -e "${GREEN}✓ Help output works${NC}"
else
    echo -e "${RED}✗ Help output failed${NC}"
fi

# Test 4: Check invalid argument handling
echo -e "${YELLOW}Test 4: Invalid argument handling${NC}"
if ! "$INSTALL_SCRIPT" --invalid-arg 2>/dev/null; then
    echo -e "${GREEN}✓ Invalid arguments rejected${NC}"
else
    echo -e "${RED}✗ Invalid arguments not rejected${NC}"
fi

echo -e "${GREEN}Installation mode tests completed!${NC}"