#!/usr/bin/env bats

# Test suite for terminal-toggle script using Bats testing framework
# Install bats with: sudo apt install bats (or see https://github.com/bats-core/bats-core)

# Setup test environment
setup() {
    # Source script location
    TERMINAL_TOGGLE="/home/andrius/dotfiles/scripts/terminal-toggle"
    STATE_FILE="$HOME/.cache/terminal-toggle-state"
    BACKUP_STATE_FILE="$HOME/.cache/terminal-toggle-state.bak"
    
    # Ensure script is executable
    chmod +x "$TERMINAL_TOGGLE"
    
    # Backup existing state if it exists
    if [ -f "$STATE_FILE" ]; then
        cp "$STATE_FILE" "$BACKUP_STATE_FILE"
    fi
    
    # Clean state for testing
    rm -f "$STATE_FILE"
    
    # Kill any existing alacritty processes to start clean
    pkill -f alacritty 2>/dev/null || true
    sleep 0.5
    
    # Ensure we have required tools
    if ! command -v wmctrl &> /dev/null || ! command -v xdotool &> /dev/null; then
        skip "Required tools (wmctrl, xdotool) not available"
    fi
}

# Teardown - restore original state
teardown() {
    # Kill any test alacritty processes
    pkill -f alacritty 2>/dev/null || true
    sleep 0.5
    
    # Restore original state file if it existed
    if [ -f "$BACKUP_STATE_FILE" ]; then
        mv "$BACKUP_STATE_FILE" "$STATE_FILE"
    else
        rm -f "$STATE_FILE"
    fi
}

# Helper function to get alacritty windows
get_alacritty_windows() {
    wmctrl -l | grep -i "Alacritty" | wc -l
}

# Helper function to get alacritty window ID
get_alacritty_window_id() {
    wmctrl -l | grep -i "Alacritty" | head -1 | awk '{print $1}' | sed 's/0x0*//'
}

# Helper function to check if window is minimized
is_window_minimized() {
    local window_id="$1"
    local hex_id=$(printf "0x%08x" "$window_id" 2>/dev/null)
    if [ -n "$hex_id" ]; then
        local state=$(xprop -id "$hex_id" WM_STATE 2>/dev/null | grep -o "Iconic\|Normal")
        [ "$state" = "Iconic" ]
    else
        return 1
    fi
}

# Helper function to check if window is active
is_window_active() {
    local window_id="$1"
    local active_window=$(xdotool getactivewindow 2>/dev/null)
    [ "$window_id" = "$active_window" ]
}

# Helper function to wait for window state change
wait_for_window_change() {
    local max_attempts=20
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        sleep 0.1
        ((attempt++))
    done
}

@test "terminal-toggle script exists and is executable" {
    [ -f "$TERMINAL_TOGGLE" ]
    [ -x "$TERMINAL_TOGGLE" ]
}

@test "required dependencies are available" {
    command -v wmctrl
    command -v xdotool
    command -v alacritty
}

@test "script creates state file on first run" {
    [ ! -f "$STATE_FILE" ]
    
    run timeout 10s "$TERMINAL_TOGGLE" toggle
    wait_for_window_change
    
    [ -f "$STATE_FILE" ]
}

@test "toggle launches alacritty when none exists" {
    # Verify no alacritty windows exist
    initial_count=$(get_alacritty_windows)
    [ "$initial_count" -eq 0 ]
    
    # Run toggle command
    run timeout 10s "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_for_window_change
    
    # Verify alacritty was launched
    final_count=$(get_alacritty_windows)
    [ "$final_count" -eq 1 ]
    
    # Verify state file was created and populated
    [ -f "$STATE_FILE" ]
    grep -q "current_toggle_id=" "$STATE_FILE"
}

@test "toggle minimizes active alacritty window" {
    # First launch alacritty
    run timeout 10s "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_for_window_change
    
    # Get the window ID
    local window_id=$(get_alacritty_window_id)
    [ -n "$window_id" ]
    
    # Convert to decimal for comparison
    local decimal_id=$(printf "%d" "0x$window_id" 2>/dev/null)
    
    # Activate the window to ensure it's active
    wmctrl -i -a "0x$window_id"
    wait_for_window_change
    
    # Verify window is not minimized initially
    run is_window_minimized "$decimal_id"
    [ "$status" -ne 0 ]
    
    # Toggle again to minimize
    run timeout 10s "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_for_window_change
    
    # Verify window is now minimized
    run is_window_minimized "$decimal_id"
    [ "$status" -eq 0 ]
}

@test "toggle restores minimized alacritty window" {
    # Launch and then minimize alacritty
    run timeout 10s "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_for_window_change
    
    local window_id=$(get_alacritty_window_id)
    local decimal_id=$(printf "%d" "0x$window_id" 2>/dev/null)
    
    # Activate and then minimize
    wmctrl -i -a "0x$window_id"
    wait_for_window_change
    
    run timeout 10s "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_for_window_change
    
    # Verify it's minimized
    run is_window_minimized "$decimal_id"
    [ "$status" -eq 0 ]
    
    # Toggle again to restore
    run timeout 10s "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_for_window_change
    
    # Verify window is restored (not minimized)
    run is_window_minimized "$decimal_id"
    [ "$status" -ne 0 ]
}

@test "new command always launches new alacritty" {
    # Launch first terminal
    run timeout 10s "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_for_window_change
    
    initial_count=$(get_alacritty_windows)
    [ "$initial_count" -eq 1 ]
    
    # Launch new terminal
    run timeout 10s "$TERMINAL_TOGGLE" new
    [ "$status" -eq 0 ]
    wait_for_window_change
    
    # Verify we now have 2 terminals
    final_count=$(get_alacritty_windows)
    [ "$final_count" -eq 2 ]
}

@test "state file tracks window IDs correctly" {
    # Launch terminal
    run timeout 10s "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_for_window_change
    
    # Check state file contains current_toggle_id
    grep -q "current_toggle_id=" "$STATE_FILE"
    
    # Extract the ID from state file
    local stored_id=$(grep "current_toggle_id=" "$STATE_FILE" | cut -d'=' -f2)
    [ -n "$stored_id" ]
    
    # Verify it matches an actual alacritty window
    local actual_window_id=$(get_alacritty_window_id)
    local decimal_actual=$(printf "%d" "0x$actual_window_id" 2>/dev/null)
    
    [ "$stored_id" = "$decimal_actual" ]
}

@test "script handles multiple terminals correctly" {
    # Launch first terminal
    run timeout 10s "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_for_window_change
    
    # Launch second terminal with 'new' command
    run timeout 10s "$TERMINAL_TOGGLE" new
    [ "$status" -eq 0 ]
    wait_for_window_change
    
    # Verify we have 2 terminals
    terminal_count=$(get_alacritty_windows)
    [ "$terminal_count" -eq 2 ]
    
    # The toggle should now work with the most recently created terminal
    # Test that toggle still works (should minimize the current tracked terminal)
    run timeout 10s "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_for_window_change
    
    # We should still have 2 terminal windows (one minimized)
    terminal_count=$(get_alacritty_windows)
    [ "$terminal_count" -eq 2 ]
}

@test "script cleans up dead window references" {
    # Launch terminal
    run timeout 10s "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_for_window_change
    
    # Get window ID from state
    local stored_id=$(grep "current_toggle_id=" "$STATE_FILE" | cut -d'=' -f2)
    [ -n "$stored_id" ]
    
    # Kill all alacritty processes
    pkill -f alacritty
    sleep 1
    
    # Try to toggle - should launch new terminal since tracked one is dead
    run timeout 10s "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_for_window_change
    
    # Should have exactly 1 terminal again
    terminal_count=$(get_alacritty_windows)
    [ "$terminal_count" -eq 1 ]
    
    # State should be updated with new window ID
    local new_stored_id=$(grep "current_toggle_id=" "$STATE_FILE" | cut -d'=' -f2)
    [ "$new_stored_id" != "$stored_id" ]
}

@test "full workflow: launch, minimize, restore, new terminal" {
    # 1. Launch first terminal (none exists)
    run timeout 10s "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_for_window_change
    
    terminal_count=$(get_alacritty_windows)
    [ "$terminal_count" -eq 1 ]
    
    # Get window details
    local window_id=$(get_alacritty_window_id)
    local decimal_id=$(printf "%d" "0x$window_id" 2>/dev/null)
    
    # 2. Activate and minimize
    wmctrl -i -a "0x$window_id"
    wait_for_window_change
    
    run timeout 10s "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_for_window_change
    
    # Verify minimized
    run is_window_minimized "$decimal_id"
    [ "$status" -eq 0 ]
    
    # 3. Restore
    run timeout 10s "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_for_window_change
    
    # Verify restored
    run is_window_minimized "$decimal_id"
    [ "$status" -ne 0 ]
    
    # 4. Launch new terminal
    run timeout 10s "$TERMINAL_TOGGLE" new
    [ "$status" -eq 0 ]
    wait_for_window_change
    
    # Should now have 2 terminals
    terminal_count=$(get_alacritty_windows)
    [ "$terminal_count" -eq 2 ]
}

@test "script handles invalid arguments gracefully" {
    run "$TERMINAL_TOGGLE" invalid_command
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "script works when state file is corrupted" {
    # Create corrupted state file
    echo "invalid_content_here" > "$STATE_FILE"
    
    # Should still work and create new clean state
    run timeout 10s "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_for_window_change
    
    # Should have launched terminal
    terminal_count=$(get_alacritty_windows)
    [ "$terminal_count" -eq 1 ]
    
    # State file should be fixed
    grep -q "current_toggle_id=" "$STATE_FILE"
    grep -q "previous_toggle_id=" "$STATE_FILE"
}

@test "focus-locking: toggle locks onto currently active terminal" {
    # Launch first terminal
    run timeout 10s "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_for_window_change
    
    local first_window_id=$(get_alacritty_window_id)
    local first_decimal_id=$(printf "%d" "0x$first_window_id" 2>/dev/null)
    
    # Launch second terminal
    run timeout 10s "$TERMINAL_TOGGLE" new
    [ "$status" -eq 0 ]
    wait_for_window_change
    
    # Get both window IDs
    local all_windows=($(wmctrl -l | grep -i "Alacritty" | awk '{print $1}' | sed 's/0x0*//'))
    [ "${#all_windows[@]}" -eq 2 ]
    
    local second_window_id=""
    for window in "${all_windows[@]}"; do
        local decimal_id=$(printf "%d" "0x$window" 2>/dev/null)
        if [ "$decimal_id" != "$first_decimal_id" ]; then
            second_window_id="$window"
            break
        fi
    done
    
    local second_decimal_id=$(printf "%d" "0x$second_window_id" 2>/dev/null)
    
    # Manually switch focus to first terminal (simulating Alt+Tab or click)
    wmctrl -i -a "0x$first_window_id"
    wait_for_window_change
    
    # Verify first terminal is now active
    local active_window=$(xdotool getactivewindow 2>/dev/null)
    [ "$active_window" = "$first_decimal_id" ]
    
    # Now toggle should lock onto the first terminal and minimize it
    run timeout 10s "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_for_window_change
    
    # Verify first terminal is minimized
    run is_window_minimized "$first_decimal_id"
    [ "$status" -eq 0 ]
    
    # Verify state file reflects the focus lock
    local stored_id=$(grep "current_toggle_id=" "$STATE_FILE" | cut -d'=' -f2)
    [ "$stored_id" = "$first_decimal_id" ]
}

@test "focus-locking: works when switching between multiple terminals" {
    # Launch three terminals
    run timeout 10s "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_for_window_change
    
    run timeout 10s "$TERMINAL_TOGGLE" new
    [ "$status" -eq 0 ]
    wait_for_window_change
    
    run timeout 10s "$TERMINAL_TOGGLE" new
    [ "$status" -eq 0 ]
    wait_for_window_change
    
    # Should have 3 terminals
    terminal_count=$(get_alacritty_windows)
    [ "$terminal_count" -eq 3 ]
    
    # Get all terminal window IDs
    local all_windows=($(wmctrl -l | grep -i "Alacritty" | awk '{print $1}' | sed 's/0x0*//'))
    [ "${#all_windows[@]}" -eq 3 ]
    
    local first_window=$(printf "%d" "0x${all_windows[0]}" 2>/dev/null)
    local second_window=$(printf "%d" "0x${all_windows[1]}" 2>/dev/null)
    local third_window=$(printf "%d" "0x${all_windows[2]}" 2>/dev/null)
    
    # Switch focus to first terminal
    wmctrl -i -a "0x${all_windows[0]}"
    wait_for_window_change
    
    # Toggle should minimize first terminal
    run timeout 10s "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_for_window_change
    
    run is_window_minimized "$first_window"
    [ "$status" -eq 0 ]
    
    # Switch focus to second terminal
    wmctrl -i -a "0x${all_windows[1]}"
    wait_for_window_change
    
    # Toggle should now minimize second terminal
    run timeout 10s "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_for_window_change
    
    run is_window_minimized "$second_window"
    [ "$status" -eq 0 ]
    
    # Verify state file tracks the second terminal
    local stored_id=$(grep "current_toggle_id=" "$STATE_FILE" | cut -d'=' -f2)
    [ "$stored_id" = "$second_window" ]
}

# Performance test
@test "toggle commands execute quickly" {
    start_time=$(date +%s%N)
    
    run timeout 10s "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_for_window_change
    
    end_time=$(date +%s%N)
    
    # Should complete in less than 10 seconds (reasonable for terminal launch)
    execution_time=$((end_time - start_time))
    [ $execution_time -lt 10000000000 ]
}