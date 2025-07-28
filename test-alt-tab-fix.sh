#!/bin/bash

# Direct test for Alt+Tab focus detection fix
# This test doesn't rely on hotkey bindings

TERMINAL_TOGGLE="/home/andrius/dotfiles/scripts/terminal-toggle"
STATE_FILE="$HOME/.cache/terminal-toggle-state"

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    pkill -f alacritty 2>/dev/null || true
    rm -f "$STATE_FILE"
    sleep 1
}

# Initial cleanup
cleanup

echo "=== Alt+Tab Focus Detection Test ==="
echo

# Step 1: Launch first terminal
echo "1. Launching first terminal..."
$TERMINAL_TOGGLE new
sleep 2

# Get first terminal ID
FIRST_ID=$(wmctrl -l | grep -i "Alacritty" | head -1 | awk '{print $1}')
FIRST_DECIMAL=$(printf "%d" "$FIRST_ID")
echo "   First terminal: $FIRST_ID (decimal: $FIRST_DECIMAL)"

# Check state file
echo "   State after first launch:"
cat "$STATE_FILE" | sed 's/^/   /'

# Step 2: Launch second terminal
echo
echo "2. Launching second terminal..."
$TERMINAL_TOGGLE new
sleep 2

# Get second terminal ID
SECOND_ID=$(wmctrl -l | grep -i "Alacritty" | tail -1 | awk '{print $1}')
SECOND_DECIMAL=$(printf "%d" "$SECOND_ID")
echo "   Second terminal: $SECOND_ID (decimal: $SECOND_DECIMAL)"

# Check state file
echo "   State after second launch:"
cat "$STATE_FILE" | sed 's/^/   /'

# Step 3: Focus first terminal using wmctrl (simulating Alt+Tab)
echo
echo "3. Focusing first terminal (simulating Alt+Tab)..."
wmctrl -i -a "$FIRST_ID"
sleep 1

ACTIVE_WINDOW=$(xdotool getactivewindow 2>/dev/null)
echo "   Active window: $ACTIVE_WINDOW"

# Step 4: Call toggle - should affect the first terminal
echo
echo "4. Calling toggle (should affect first terminal)..."
$TERMINAL_TOGGLE toggle
sleep 1

# Check if first terminal is minimized
FIRST_STATE=$(xprop -id "$FIRST_ID" WM_STATE 2>/dev/null | grep -o "Iconic\|Normal")
SECOND_STATE=$(xprop -id "$SECOND_ID" WM_STATE 2>/dev/null | grep -o "Iconic\|Normal")

echo "   First terminal state: $FIRST_STATE"
echo "   Second terminal state: $SECOND_STATE"

# Check state file after toggle
echo "   State after toggle:"
cat "$STATE_FILE" | sed 's/^/   /'

# Step 5: Verify the fix worked
echo
echo "5. Results:"
if [ "$FIRST_STATE" = "Iconic" ]; then
    echo "   ✓ SUCCESS: First terminal was minimized (focus detection worked)"
    
    # Test restore as well
    echo
    echo "6. Testing restore..."
    $TERMINAL_TOGGLE toggle
    sleep 1
    
    FIRST_STATE_AFTER=$(xprop -id "$FIRST_ID" WM_STATE 2>/dev/null | grep -o "Iconic\|Normal")
    echo "   First terminal state after restore: $FIRST_STATE_AFTER"
    
    if [ "$FIRST_STATE_AFTER" = "Normal" ]; then
        echo "   ✓ SUCCESS: First terminal was restored"
    else
        echo "   ✗ FAIL: First terminal was not restored"
    fi
else
    echo "   ✗ FAIL: First terminal was not minimized (focus detection failed)"
    echo "   This suggests the Alt+Tab focus detection is not working"
fi

# Final state
echo
echo "Final state:"
cat "$STATE_FILE" | sed 's/^//'

cleanup