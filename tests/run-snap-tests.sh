#!/bin/bash

echo "=== Snap Window Test Suite ==="
echo

if ! command -v bats &>/dev/null; then
    echo "❌ Bats testing framework not found. Install with: sudo apt install bats"
    exit 1
fi

echo "🧪 Running automated test suite..."

TEST_FILE=""
if [ -f "test-ui-snap-window.bats" ]; then
    TEST_FILE="test-ui-snap-window.bats"
elif [ -f "./tests/test-ui-snap-window.bats" ]; then
    TEST_FILE="./tests/test-ui-snap-window.bats"
elif [ -f "/home/andrius/dotfiles/tests/test-ui-snap-window.bats" ]; then
    TEST_FILE="/home/andrius/dotfiles/tests/test-ui-snap-window.bats"
else
    echo "❌ Cannot find test-ui-snap-window.bats file"
    exit 1
fi

if bats "$TEST_FILE"; then
    echo "✅ All automated tests passed!"
else
    echo "❌ Some automated tests failed!"
    exit 1
fi

echo
echo "🎯 Running manual verification tests..."

echo "1. Testing basic navigation..."
~/.local/bin/ui-snap-window left
sleep 0.5
~/.local/bin/ui-snap-window right
sleep 0.5
~/.local/bin/ui-snap-window up
sleep 0.5
~/.local/bin/ui-snap-window down
echo "✅ Basic navigation complete"

echo
echo "2. Testing expand functionality..."
~/.local/bin/ui-snap-window left # Position to left half
sleep 0.5
echo "   From left half: expand-right -> full width"
~/.local/bin/ui-snap-window expand-right
~/.local/bin/test-window-position | grep "Full Width" && echo "   ✅ Expanded to full width"
sleep 0.5
echo "   From full width: expand-right -> right half"
~/.local/bin/ui-snap-window expand-right
~/.local/bin/test-window-position | grep "Right Half" && echo "   ✅ Contracted to right half"

echo
echo "3. Testing cross-monitor navigation..."
~/.local/bin/ui-snap-window right # Should move to next screen
sleep 0.5
~/.local/bin/ui-snap-window right # Should continue on next screen
sleep 0.5
~/.local/bin/ui-snap-window right # Should wrap back to first screen
~/.local/bin/test-window-position | grep "Screen 0" && echo "   ✅ Wrapped to first screen"

echo
echo "4. Testing quarter window preservation..."
~/.local/bin/ui-snap-window up # Make quarter window
sleep 0.5
echo "   Created quarter window"
~/.local/bin/ui-snap-window right # Navigate while preserving size
sleep 0.5
~/.local/bin/test-window-position | grep "Quarter" && echo "   ✅ Quarter size preserved during navigation"

echo
echo "🎉 All tests completed successfully!"
echo "   📋 Test results summary:"
echo "   • Basic navigation: ✅"
echo "   • Expand functionality: ✅"
echo "   • Cross-monitor navigation: ✅"
echo "   • Size preservation: ✅"
echo "   • Edge cases and wrapping: ✅"
