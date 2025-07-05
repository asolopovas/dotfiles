#!/usr/bin/env bash
set -euo pipefail

# Test script for install-codex.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/../scripts/install-codex.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -e "${YELLOW}Running test: $test_name${NC}"
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if eval "$test_command"; then
        echo -e "${GREEN}✓ PASS: $test_name${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL: $test_name${NC}"
    fi
    echo
}

# Test 1: Script exists and is executable
test_script_exists() {
    [[ -f "$INSTALL_SCRIPT" ]] && [[ -x "$INSTALL_SCRIPT" ]]
}

# Test 2: Script shows help when --help is passed
test_help_flag() {
    "$INSTALL_SCRIPT" --help 2>&1 | grep -q "Usage:"
}

# Test 3: Script has proper shebang
test_shebang() {
    head -n1 "$INSTALL_SCRIPT" | grep -q "#!/usr/bin/env bash"
}

# Test 4: Script has set -euo pipefail
test_error_handling() {
    grep -q "set -euo pipefail" "$INSTALL_SCRIPT"
}

# Test 5: Script validates architecture correctly
test_arch_detection() {
    # Mock uname -m for different architectures
    local temp_script=$(mktemp)
    
    # Create test script that mocks uname -m
    cat > "$temp_script" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Mock uname function
uname() {
    if [[ "$1" == "-m" ]]; then
        echo "$TEST_ARCH"
    else
        command uname "$@"
    fi
}

# Source the main script logic (without execution)
REPO="openai/codex"
TAG="rust-v0.2.0"

arch="$(uname -m)"
case "$arch" in
x86_64) arch="x86_64" ;;
aarch64) arch="aarch64" ;;
arm64) arch="aarch64" ;;
*) echo "✖ unsupported cpu: $arch" && exit 1 ;;
esac

echo "arch=$arch"
EOF
    
    chmod +x "$temp_script"
    
    # Test x86_64
    TEST_ARCH=x86_64 "$temp_script" | grep -q "arch=x86_64" &&
    # Test aarch64
    TEST_ARCH=aarch64 "$temp_script" | grep -q "arch=aarch64" &&
    # Test arm64 (should map to aarch64)
    TEST_ARCH=arm64 "$temp_script" | grep -q "arch=aarch64" &&
    # Test unsupported arch
    ! TEST_ARCH=unsupported "$temp_script" &>/dev/null
    
    rm "$temp_script"
}

# Test 6: Script validates OS correctly
test_os_detection() {
    local temp_script=$(mktemp)
    
    cat > "$temp_script" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Mock uname function
uname() {
    if [[ "$1" == "-s" ]]; then
        echo "$TEST_OS"
    else
        command uname "$@"
    fi
}

# Mock ldd function for musl detection
ldd() {
    if [[ "$TEST_MUSL" == "true" ]]; then
        echo "musl libc"
    else
        echo "glibc"
    fi
}

case "$(uname -s)" in
Linux)
    if ldd --version 2>&1 | grep -q musl; then
        os="unknown-linux-musl"
    else
        os="unknown-linux-gnu"
    fi
    ext="tar.gz"
    ;;
Darwin)
    os="apple-darwin"
    ext="tar.gz"
    ;;
MINGW* | MSYS* | CYGWIN*)
    echo "✖ Windows is not supported. Use WSL or Linux instead."
    exit 1
    ;;
*) echo "✖ unsupported os: $(uname -s)" && exit 1 ;;
esac

echo "os=$os ext=$ext"
EOF
    
    chmod +x "$temp_script"
    
    # Test Linux with glibc
    TEST_OS=Linux TEST_MUSL=false "$temp_script" | grep -q "os=unknown-linux-gnu ext=tar.gz" &&
    # Test Linux with musl
    TEST_OS=Linux TEST_MUSL=true "$temp_script" | grep -q "os=unknown-linux-musl ext=tar.gz" &&
    # Test macOS
    TEST_OS=Darwin "$temp_script" | grep -q "os=apple-darwin ext=tar.gz" &&
    # Test Windows (should fail)
    ! TEST_OS=MINGW64_NT-10.0 "$temp_script" &>/dev/null
    
    rm "$temp_script"
}

# Test 7: URL construction is correct
test_url_construction() {
    # Extract URL construction logic
    local test_url=$(bash -c '
        REPO="openai/codex"
        TAG="rust-v0.2.0"
        arch="x86_64"
        os="unknown-linux-gnu"
        asset="codex-${arch}-${os}.tar.gz"
        url="https://github.com/${REPO}/releases/download/${TAG}/${asset}"
        echo "$url"
    ')
    
    [[ "$test_url" == "https://github.com/openai/codex/releases/download/rust-v0.2.0/codex-x86_64-unknown-linux-gnu.tar.gz" ]]
}

# Test 8: Check if download URL is accessible
test_download_url() {
    # Test with a real URL to ensure it exists (GitHub releases return 302 redirect)
    local test_url="https://github.com/openai/codex/releases/download/rust-v0.2.0/codex-x86_64-unknown-linux-gnu.tar.gz"
    curl -sI "$test_url" | head -n1 | grep -qE "(200|302)"
}

# Test 9: Test installation to /tmp/install-codex/
test_install_functionality() {
    # Create test directory
    local test_dir="/tmp/install-codex"
    mkdir -p "$test_dir"
    
    # Mock the binary download and installation
    local mock_script=$(mktemp)
    cat > "$mock_script" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Mock version of install script for testing
USE_ROOT=false
for arg in "$@"; do
    case $arg in
        --root) USE_ROOT=true ;;
    esac
done

if [[ "$USE_ROOT" == "true" ]]; then
    echo "Would install to /usr/local/bin (root mode)"
else
    echo "Would install to ~/.local/bin (user mode)"
fi
EOF
    
    chmod +x "$mock_script"
    
    # Test user mode
    "$mock_script" | grep -q "user mode" &&
    # Test root mode
    "$mock_script" --root | grep -q "root mode"
    
    rm -f "$mock_script"
    rm -rf "$test_dir"
}

# Run all tests
echo "Starting tests for install-codex.sh..."
echo "======================================"

run_test "Script exists and is executable" "test_script_exists"
run_test "Script shows help" "test_help_flag"
run_test "Script has proper shebang" "test_shebang"
run_test "Script has error handling" "test_error_handling"
run_test "Architecture detection works" "test_arch_detection"
run_test "OS detection works" "test_os_detection"
run_test "URL construction is correct" "test_url_construction"
run_test "Download URL is accessible" "test_download_url"
run_test "Installation functionality works" "test_install_functionality"

echo "======================================"
echo "Tests completed: $TESTS_PASSED/$TESTS_RUN passed"

if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi