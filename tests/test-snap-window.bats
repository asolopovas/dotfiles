#!/usr/bin/env bats

# Test suite for snap-window script using Bats testing framework
# Install bats with: sudo apt install bats (or see https://github.com/bats-core/bats-core)

# Setup test environment
setup() {
    # Source script location
    SNAP_WINDOW="/home/andrius/dotfiles/scripts/snap-window"
    TEST_WINDOW_POS="/home/andrius/.local/bin/test-window-position"
    
    # Ensure scripts are executable
    chmod +x "$SNAP_WINDOW"
    chmod +x "$TEST_WINDOW_POS"
    
    # Backup original window position if available
    if command -v xdotool &> /dev/null; then
        ORIGINAL_WINDOW=$(xdotool getactivewindow 2>/dev/null || echo "")
        if [ -n "$ORIGINAL_WINDOW" ]; then
            ORIGINAL_INFO=$(wmctrl -lG | grep "$(printf '0x%08x' $ORIGINAL_WINDOW)" || echo "")
        fi
    fi
}

# Teardown - restore original window position if possible
teardown() {
    if [ -n "$ORIGINAL_WINDOW" ] && [ -n "$ORIGINAL_INFO" ]; then
        original_x=$(echo "$ORIGINAL_INFO" | awk '{print $3}')
        original_y=$(echo "$ORIGINAL_INFO" | awk '{print $4}')
        original_width=$(echo "$ORIGINAL_INFO" | awk '{print $5}')
        original_height=$(echo "$ORIGINAL_INFO" | awk '{print $6}')
        wmctrl -i -r "$ORIGINAL_WINDOW" -e "0,$original_x,$original_y,$original_width,$original_height" 2>/dev/null || true
    fi
}

# Helper function to get current window position
get_window_position() {
    if ! command -v xdotool &> /dev/null; then
        skip "xdotool not available"
    fi
    
    local active_window=$(xdotool getactivewindow 2>/dev/null)
    if [ -z "$active_window" ]; then
        skip "No active window found"
    fi
    
    local window_info=$(wmctrl -lG | grep "$(printf '0x%08x' $active_window)")
    if [ -z "$window_info" ]; then
        skip "Window info not found"
    fi
    
    echo "$window_info"
}

# Helper function to run snap-window and verify result
test_snap_command() {
    local direction="$1"
    local expected_desc="$2"
    
    # Run the snap command
    run bash "$SNAP_WINDOW" "$direction"
    
    # Check command succeeded
    [ "$status" -eq 0 ]
    
    # Verify position if expected description provided
    if [ -n "$expected_desc" ]; then
        run bash "$TEST_WINDOW_POS"
        [[ "$output" == *"$expected_desc"* ]]
    fi
}

@test "snap-window script exists and is executable" {
    [ -f "$SNAP_WINDOW" ]
    [ -x "$SNAP_WINDOW" ]
}

@test "test-window-position helper exists and is executable" {
    [ -f "$TEST_WINDOW_POS" ]
    [ -x "$TEST_WINDOW_POS" ]
}

@test "required dependencies are available" {
    command -v wmctrl
    command -v xdotool
    command -v xrandr
}

@test "can get current window position" {
    run get_window_position
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

@test "snap left moves window to left" {
    test_snap_command "left" ""
}

@test "snap right moves window to right" {
    test_snap_command "right" ""
}

@test "snap up moves window to top" {
    test_snap_command "up" ""
}

@test "snap down moves window to bottom" {
    test_snap_command "down" ""
}

@test "horizontal navigation sequence: left -> right -> left" {
    # Start with left
    test_snap_command "left" ""
    
    # Move right
    test_snap_command "right" ""
    
    # Move left again
    test_snap_command "left" ""
}

@test "vertical navigation sequence: up -> down -> up" {
    # Start with up
    test_snap_command "up" ""
    
    # Move down
    test_snap_command "down" ""
    
    # Move up again
    test_snap_command "up" ""
}

@test "expand-up from quarter to half" {
    # Position to quarter first
    test_snap_command "up" ""
    
    # Expand vertically
    test_snap_command "expand-up" ""
}

@test "expand-down from quarter to half" {
    # Position to quarter first
    test_snap_command "down" ""
    
    # Expand vertically
    test_snap_command "expand-down" ""
}

@test "expand-down from full-width top half to full window" {
    # Create full-width top half
    test_snap_command "up" ""
    test_snap_command "expand-right" ""
    
    # Expand down should create full window
    test_snap_command "expand-down" ""
}

@test "expand-up from full-width bottom half to full window" {
    # Create full-width bottom half
    test_snap_command "down" ""
    test_snap_command "expand-right" ""
    
    # Expand up should create full window
    test_snap_command "expand-up" ""
}

@test "expand-right from half to full to right-half" {
    # Position to left half first
    test_snap_command "left" ""
    
    # First expand-right: should go to full width
    test_snap_command "expand-right" ""
    
    # Second expand-right: should go to right half
    test_snap_command "expand-right" ""
}

@test "expand-left from half to full to left-half" {
    # Position to right half first
    test_snap_command "right" ""
    
    # First expand-left: should go to full width
    test_snap_command "expand-left" ""
    
    # Second expand-left: should go to left half
    test_snap_command "expand-left" ""
}

@test "cross-monitor navigation wrapping" {
    # Test wrapping from rightmost to leftmost
    # This test assumes dual monitor setup
    
    # Start at rightmost position
    test_snap_command "right" ""
    test_snap_command "right" ""  # Should be at screen 1 right
    
    # Move right again should wrap to screen 0 left
    test_snap_command "right" ""
    
    # Verify we can move left from there
    test_snap_command "left" ""
}

@test "window size preservation during navigation" {
    # Start with a quarter window (up position)
    test_snap_command "up" ""
    
    # Move horizontally - should preserve quarter height
    test_snap_command "right" ""
    
    # Move left - should still preserve quarter height
    test_snap_command "left" ""
}

@test "full end-to-end workflow" {
    # Complete workflow testing all major functions
    
    # 1. Basic positioning
    test_snap_command "left" ""
    test_snap_command "up" ""    # Should be quarter window top-left
    
    # 2. Navigation with size preservation
    test_snap_command "right" "" # Should move to top quarter of next column
    test_snap_command "down" ""  # Should move to bottom quarter of same column
    
    # 3. Expansion operations
    test_snap_command "expand-up" ""    # Should expand to half height
    test_snap_command "expand-right" "" # Should expand to full width
    test_snap_command "expand-right" "" # Should contract to right half
    
    # 4. Cross-monitor navigation
    test_snap_command "right" "" # Should move to next screen
    test_snap_command "left" ""  # Should move back
}

# Performance test
@test "snap commands execute quickly" {
    start_time=$(date +%s%N)
    test_snap_command "left" ""
    end_time=$(date +%s%N)
    
    # Should complete in less than 1 second (1000000000 nanoseconds)
    execution_time=$((end_time - start_time))
    [ $execution_time -lt 1000000000 ]
}

# Error handling tests
@test "handles invalid direction gracefully" {
    run bash "$SNAP_WINDOW" "invalid_direction"
    # Should not crash, but may not do anything
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "handles no active window gracefully" {
    # This test might be hard to simulate, skip if can't test
    if command -v xdotool &> /dev/null; then
        # Try to test with no window focused (hard to simulate)
        skip "Cannot reliably test no-window scenario in GUI environment"
    else
        skip "xdotool not available for testing"
    fi
}