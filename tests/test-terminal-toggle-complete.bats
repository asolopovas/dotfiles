#!/usr/bin/env bats

# Complete test suite for terminal-toggle functionality
# Tests the full workflow: super+enter cycles and focus-locking behavior

# Setup test environment
setup() {
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
    sleep 1
    
    # Ensure we have required tools
    if ! command -v wmctrl &> /dev/null || ! command -v xdotool &> /dev/null; then
        skip "Required tools (wmctrl, xdotool) not available"
    fi
}

# Teardown - restore original state
teardown() {
    # Kill any test alacritty processes
    pkill -f alacritty 2>/dev/null || true
    sleep 1
    
    # Restore original state file if it existed
    if [ -f "$BACKUP_STATE_FILE" ]; then
        mv "$BACKUP_STATE_FILE" "$STATE_FILE"
    else
        rm -f "$STATE_FILE"
    fi
}

# Helper function to get alacritty window count
get_alacritty_count() {
    wmctrl -l | grep -i "Alacritty" | wc -l
}

# Helper function to get alacritty window ID (first one)
get_alacritty_window_id() {
    wmctrl -l | grep -i "Alacritty" | head -1 | awk '{print $1}' | sed 's/0x0*//'
}

# Helper function to get all alacritty window IDs
get_all_alacritty_window_ids() {
    wmctrl -l | grep -i "Alacritty" | awk '{print $1}' | sed 's/0x0*//'
}

# Helper function to get window geometry info
get_window_info() {
    local window_id="$1"
    local hex_id=$(printf "0x%08x" "$window_id" 2>/dev/null)
    if [ -n "$hex_id" ]; then
        wmctrl -lG | grep "$hex_id"
    fi
}

# Helper function to check if window is minimized (more robust)
is_window_minimized() {
    local window_id="$1"
    local hex_id=$(printf "0x%08x" "$window_id" 2>/dev/null)
    if [ -n "$hex_id" ]; then
        # Check WM_STATE property
        local wm_state=$(xprop -id "$hex_id" WM_STATE 2>/dev/null)
        if echo "$wm_state" | grep -q "Iconic"; then
            return 0  # Minimized
        elif echo "$wm_state" | grep -q "Normal"; then
            return 1  # Not minimized
        else
            # Fallback: check if window appears in wmctrl geometry list
            local window_info=$(get_window_info "$window_id")
            if [ -z "$window_info" ]; then
                return 0  # Not in geometry list, likely minimized
            else
                return 1  # In geometry list, likely visible
            fi
        fi
    else
        return 1
    fi
}

# Helper function to check if window is normal (visible)
is_window_normal() {
    local window_id="$1"
    local hex_id=$(printf "0x%08x" "$window_id" 2>/dev/null)
    if [ -n "$hex_id" ]; then
        # Check WM_STATE property
        local wm_state=$(xprop -id "$hex_id" WM_STATE 2>/dev/null)
        if echo "$wm_state" | grep -q "Normal"; then
            return 0  # Normal/visible
        elif echo "$wm_state" | grep -q "Iconic"; then
            return 1  # Minimized
        else
            # Fallback: check if window appears in wmctrl geometry list
            local window_info=$(get_window_info "$window_id")
            if [ -n "$window_info" ]; then
                return 0  # In geometry list, likely visible
            else
                return 1  # Not in geometry list, likely minimized
            fi
        fi
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

# Helper function to wait and verify state
wait_and_verify() {
    sleep 1
}

# Helper function to get state file current_toggle_id
get_current_toggle_id() {
    if [ -f "$STATE_FILE" ]; then
        grep "current_toggle_id=" "$STATE_FILE" | cut -d'=' -f2
    fi
}

@test "FULL CYCLE: Complete super+enter toggle cycle" {
    echo "=== Starting complete toggle cycle test ==="
    
    # STEP 1: Initial super+enter - should launch terminal
    echo "STEP 1: Launch terminal with super+enter (no terminals exist)"
    initial_count=$(get_alacritty_count)
    [ "$initial_count" -eq 0 ]
    
    run timeout 15s "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_and_verify
    
    # CONFIRM: Terminal launched
    final_count=$(get_alacritty_count)
    echo "  ✓ Terminal count: $initial_count -> $final_count"
    [ "$final_count" -eq 1 ]
    
    # Get window details
    local window_id=$(get_alacritty_window_id)
    local decimal_id=$(printf "%d" "0x$window_id" 2>/dev/null)
    echo "  ✓ Terminal window ID: $decimal_id (hex: $window_id)"
    
    # CONFIRM: Window is normal (visible)
    run is_window_normal "$decimal_id"
    [ "$status" -eq 0 ]
    echo "  ✓ Terminal is visible (Normal state)"
    
    # CONFIRM: State file created with correct ID
    local stored_id=$(get_current_toggle_id)
    [ "$stored_id" = "$decimal_id" ]
    echo "  ✓ State file tracking: $stored_id"
    
    # STEP 2: Second super+enter - should minimize terminal
    echo "STEP 2: Minimize terminal with super+enter (terminal is active)"
    
    # Make sure terminal is active first
    wmctrl -i -a "0x$window_id"
    wait_and_verify
    
    run timeout 15s "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_and_verify
    
    # CONFIRM: Terminal minimized
    run is_window_minimized "$decimal_id"
    [ "$status" -eq 0 ]
    echo "  ✓ Terminal is minimized (Iconic state)"
    
    # CONFIRM: Still only one terminal
    current_count=$(get_alacritty_count)
    [ "$current_count" -eq 1 ]
    echo "  ✓ Terminal count unchanged: $current_count"
    
    # STEP 3: Third super+enter - should restore terminal
    echo "STEP 3: Restore terminal with super+enter (terminal is minimized)"
    
    run timeout 15s "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_and_verify
    
    # CONFIRM: Terminal restored
    run is_window_normal "$decimal_id"
    [ "$status" -eq 0 ]
    echo "  ✓ Terminal is restored (Normal state)"
    
    # CONFIRM: Terminal is now active
    run is_window_active "$decimal_id"
    [ "$status" -eq 0 ]
    echo "  ✓ Terminal is active"
    
    echo "=== First toggle cycle completed successfully ==="
}

@test "NEW TERMINAL: super+shift+enter and focus shift" {
    echo "=== Testing new terminal launch and focus shift ==="
    
    # SETUP: Launch first terminal
    echo "SETUP: Launch first terminal"
    run timeout 15s "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_and_verify
    
    local first_window_id=$(get_alacritty_window_id)
    local first_decimal_id=$(printf "%d" "0x$first_window_id" 2>/dev/null)
    echo "  ✓ First terminal ID: $first_decimal_id"
    
    # STEP 1: Launch new terminal with super+shift+enter
    echo "STEP 1: Launch new terminal with super+shift+enter"
    
    run timeout 15s "$TERMINAL_TOGGLE" new
    [ "$status" -eq 0 ]
    wait_and_verify
    
    # CONFIRM: Now have 2 terminals
    terminal_count=$(get_alacritty_count)
    [ "$terminal_count" -eq 2 ]
    echo "  ✓ Terminal count: 1 -> $terminal_count"
    
    # Get all window IDs and find the new one
    local all_windows=($(get_all_alacritty_window_ids))
    local second_window_id=""
    for window in "${all_windows[@]}"; do
        local decimal_id=$(printf "%d" "0x$window" 2>/dev/null)
        if [ "$decimal_id" != "$first_decimal_id" ]; then
            second_window_id="$window"
            break
        fi
    done
    
    local second_decimal_id=$(printf "%d" "0x$second_window_id" 2>/dev/null)
    echo "  ✓ Second terminal ID: $second_decimal_id"
    
    # CONFIRM: Focus shifted to new terminal
    local stored_id=$(get_current_toggle_id)
    [ "$stored_id" = "$second_decimal_id" ]
    echo "  ✓ Focus shifted to new terminal: $stored_id"
    
    # STEP 2: Test toggle cycle with new terminal
    echo "STEP 2: Test toggle cycle with new terminal"
    
    # Make sure new terminal is active
    wmctrl -i -a "0x$second_window_id"
    wait_and_verify
    
    # Minimize new terminal
    run timeout 15s "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_and_verify
    
    # CONFIRM: New terminal minimized
    run is_window_minimized "$second_decimal_id"
    [ "$status" -eq 0 ]
    echo "  ✓ New terminal minimized"
    
    # Restore new terminal
    run timeout 15s "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_and_verify
    
    # CONFIRM: New terminal restored
    run is_window_normal "$second_decimal_id"
    [ "$status" -eq 0 ]
    echo "  ✓ New terminal restored"
    
    echo "=== New terminal test completed successfully ==="
}

@test "FOCUS SWITCHING: Alt+Tab simulation and lock behavior" {
    echo "=== Testing focus switching and lock behavior ==="
    
    # SETUP: Launch two terminals
    echo "SETUP: Launch two terminals"
    run timeout 15s "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_and_verify
    
    run timeout 15s "$TERMINAL_TOGGLE" new
    [ "$status" -eq 0 ]
    wait_and_verify
    
    # Get both terminal IDs
    local all_windows=($(get_all_alacritty_window_ids))
    [ "${#all_windows[@]}" -eq 2 ]
    
    local first_window_id="${all_windows[0]}"
    local second_window_id="${all_windows[1]}"
    local first_decimal_id=$(printf "%d" "0x$first_window_id" 2>/dev/null)
    local second_decimal_id=$(printf "%d" "0x$second_window_id" 2>/dev/null)
    
    echo "  ✓ First terminal: $first_decimal_id"
    echo "  ✓ Second terminal: $second_decimal_id"
    
    # Current focus should be on second terminal (most recently created)
    local initial_stored_id=$(get_current_toggle_id)
    [ "$initial_stored_id" = "$second_decimal_id" ]
    echo "  ✓ Initial focus on second terminal: $initial_stored_id"
    
    # STEP 1: Simulate Alt+Tab to first terminal
    echo "STEP 1: Simulate Alt+Tab to first terminal"
    wmctrl -i -a "0x$first_window_id"
    wait_and_verify
    
    # CONFIRM: First terminal is now active
    run is_window_active "$first_decimal_id"
    [ "$status" -eq 0 ]
    echo "  ✓ First terminal is now active"
    
    # STEP 2: Toggle should now lock onto first terminal and minimize it
    echo "STEP 2: Toggle should lock onto first terminal"
    
    run timeout 15s "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_and_verify
    
    # CONFIRM: First terminal minimized
    run is_window_minimized "$first_decimal_id"
    [ "$status" -eq 0 ]
    echo "  ✓ First terminal minimized (focus locked)"
    
    # CONFIRM: State file updated to track first terminal
    local updated_stored_id=$(get_current_toggle_id)
    [ "$updated_stored_id" = "$first_decimal_id" ]
    echo "  ✓ State updated to track first terminal: $updated_stored_id"
    
    # STEP 3: Restore first terminal
    echo "STEP 3: Restore first terminal"
    
    run timeout 15s "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_and_verify
    
    # CONFIRM: First terminal restored
    run is_window_normal "$first_decimal_id"
    [ "$status" -eq 0 ]
    echo "  ✓ First terminal restored"
    
    # STEP 4: Switch to second terminal and test lock
    echo "STEP 4: Switch to second terminal and test lock"
    wmctrl -i -a "0x$second_window_id"
    wait_and_verify
    
    # Toggle should lock onto second terminal
    run timeout 15s "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_and_verify
    
    # CONFIRM: Second terminal minimized
    run is_window_minimized "$second_decimal_id"
    [ "$status" -eq 0 ]
    echo "  ✓ Second terminal minimized (focus re-locked)"
    
    # CONFIRM: State file updated to track second terminal
    local final_stored_id=$(get_current_toggle_id)
    [ "$final_stored_id" = "$second_decimal_id" ]
    echo "  ✓ State updated to track second terminal: $final_stored_id"
    
    echo "=== Focus switching test completed successfully ==="
}

@test "COMPLETE WORKFLOW: Full end-to-end test" {
    echo "=== COMPLETE WORKFLOW TEST ==="
    
    # This test combines all the above scenarios in sequence
    
    echo "Phase 1: Initial toggle cycle"
    # Launch -> Minimize -> Restore
    run timeout 15s "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_and_verify
    
    local first_id=$(get_alacritty_window_id)
    local first_decimal=$(printf "%d" "0x$first_id" 2>/dev/null)
    
    wmctrl -i -a "0x$first_id"
    wait_and_verify
    
    run timeout 15s "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_and_verify
    run is_window_minimized "$first_decimal"
    [ "$status" -eq 0 ]
    
    run timeout 15s "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_and_verify
    run is_window_normal "$first_decimal"
    [ "$status" -eq 0 ]
    echo "  ✓ Phase 1 completed"
    
    echo "Phase 2: New terminal and focus shift"
    run timeout 15s "$TERMINAL_TOGGLE" new
    [ "$status" -eq 0 ]
    wait_and_verify
    
    [ "$(get_alacritty_count)" -eq 2 ]
    
    local all_windows=($(get_all_alacritty_window_ids))
    local second_id=""
    for window in "${all_windows[@]}"; do
        local decimal_id=$(printf "%d" "0x$window" 2>/dev/null)
        if [ "$decimal_id" != "$first_decimal" ]; then
            second_id="$window"
            break
        fi
    done
    local second_decimal=$(printf "%d" "0x$second_id" 2>/dev/null)
    
    [ "$(get_current_toggle_id)" = "$second_decimal" ]
    echo "  ✓ Phase 2 completed"
    
    echo "Phase 3: Focus switching test"
    wmctrl -i -a "0x$first_id"
    wait_and_verify
    
    run timeout 15s "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_and_verify
    
    run is_window_minimized "$first_decimal"
    [ "$status" -eq 0 ]
    [ "$(get_current_toggle_id)" = "$first_decimal" ]
    echo "  ✓ Phase 3 completed"
    
    echo "=== COMPLETE WORKFLOW PASSED ==="
}