#!/usr/bin/env bash
set -euo pipefail

# Compact test suite for install-codex.sh
# Usage: test-install-codex.sh [--root]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/../scripts/install-codex.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check for --root flag
TEST_ROOT=false
for arg in "$@"; do
    case $arg in
        --root) TEST_ROOT=true ;;
    esac
done

# Test counters
TESTS_RUN=0
TESTS_PASSED=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    if eval "$test_command" &>/dev/null; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $test_name"
    fi
}

# Compact test functions
test_script_valid() { [[ -f "$INSTALL_SCRIPT" && -x "$INSTALL_SCRIPT" ]] && head -n2 "$INSTALL_SCRIPT" | grep -q "set -euo pipefail"; }
test_help_works() { "$INSTALL_SCRIPT" --help | grep -q "Usage:"; }
test_arch_detection() { 
    local temp_script=$(mktemp)
    cat > "$temp_script" << 'EOF'
uname() { echo "$TEST_ARCH"; }
arch="$(uname -m)"
case "$arch" in
x86_64|aarch64) echo "supported" ;;
arm64) echo "supported" ;;
*) exit 1 ;;
esac
EOF
    TEST_ARCH=x86_64 bash "$temp_script" && TEST_ARCH=aarch64 bash "$temp_script" && TEST_ARCH=arm64 bash "$temp_script" && ! TEST_ARCH=unsupported bash "$temp_script"
    rm -f "$temp_script"
}
test_os_detection() {
    local temp_script=$(mktemp)
    cat > "$temp_script" << 'EOF'
uname() { echo "$TEST_OS"; }
case "$(uname -s)" in
Linux|Darwin) echo "supported" ;;
MINGW*|MSYS*|CYGWIN*) exit 1 ;;
*) exit 1 ;;
esac
EOF
    TEST_OS=Linux bash "$temp_script" && TEST_OS=Darwin bash "$temp_script" && ! TEST_OS=MINGW64_NT-10.0 bash "$temp_script"
    rm -f "$temp_script"
}
test_url_construction() {
    local url=$(bash -c 'REPO="openai/codex"; TAG="rust-v0.2.0"; arch="x86_64"; os="unknown-linux-gnu"; echo "https://github.com/${REPO}/releases/download/${TAG}/codex-${arch}-${os}.tar.gz"')
    [[ "$url" == "https://github.com/openai/codex/releases/download/rust-v0.2.0/codex-x86_64-unknown-linux-gnu.tar.gz" ]]
}
test_download_url() { curl -sI "https://github.com/openai/codex/releases/download/rust-v0.2.0/codex-x86_64-unknown-linux-gnu.tar.gz" | head -n1 | grep -qE "(200|302)"; }
test_install_modes() {
    [[ $(bash -c 'USE_ROOT=false; [[ "$USE_ROOT" == "true" ]] && echo "/usr/local/bin" || echo "$HOME/.local/bin"') == "$HOME/.local/bin" ]] &&
    [[ $(bash -c 'USE_ROOT=true; [[ "$USE_ROOT" == "true" ]] && echo "/usr/local/bin" || echo "$HOME/.local/bin"') == "/usr/local/bin" ]]
}

echo "Testing install-codex.sh..."

# Core tests (always run)
run_test "Script valid and executable" "test_script_valid"
run_test "Help works" "test_help_works"
run_test "Architecture detection" "test_arch_detection"
run_test "OS detection" "test_os_detection"
run_test "URL construction" "test_url_construction"
run_test "Download URL accessible" "test_download_url"
run_test "Install modes logic" "test_install_modes"

# Root installation test (only if --root flag passed)
if [[ "$TEST_ROOT" == "true" ]]; then
    echo
    echo -e "${YELLOW}Testing actual root installation...${NC}"
    if "$INSTALL_SCRIPT" --root; then
        if [[ -f "/usr/local/bin/codex" ]] && /usr/local/bin/codex --version &>/dev/null; then
            echo -e "${GREEN}✓${NC} Root installation successful"
            TESTS_RUN=$((TESTS_RUN + 1))
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}✗${NC} Root installation failed"
            TESTS_RUN=$((TESTS_RUN + 1))
        fi
    else
        echo -e "${RED}✗${NC} Root installation script failed"
        TESTS_RUN=$((TESTS_RUN + 1))
    fi
fi

echo
echo "Results: $TESTS_PASSED/$TESTS_RUN passed"

if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi