#!/usr/bin/env bats

# Complete terminal toggle functionality test suite
# Tests the full workflow as specified:
# 1. Initial super+enter (launch) -> super+enter (minimize) -> super+enter (restore)
# 2. super+shift+enter (new terminal) and repeat cycle with new terminal
# 3. Alt+Tab switch and repeat cycle with different terminal

setup() {
    TERMINAL_TOGGLE="/home/andrius/dotfiles/scripts/terminal-toggle"
    STATE_FILE="$HOME/.cache/terminal-toggle-state"
    BACKUP_STATE_FILE="$HOME/.cache/terminal-toggle-state.bak"
    
    # Ensure script is executable
    chmod +x "$TERMINAL_TOGGLE"
    
    # Backup existing state
    if [ -f "$STATE_FILE" ]; then
        cp "$STATE_FILE" "$BACKUP_STATE_FILE"
    fi
    
    # Clean state for testing
    rm -f "$STATE_FILE"
    
    # Kill any existing alacritty processes
    pkill -f alacritty 2>/dev/null || true
    sleep 1
    
    # Verify required tools
    if ! command -v wmctrl &> /dev/null || ! command -v xdotool &> /dev/null; then
        skip "Required tools (wmctrl, xdotool) not available"
    fi
}

teardown() {
    # Clean up test processes
    pkill -f alacritty 2>/dev/null || true
    sleep 1
    
    # Restore original state
    if [ -f "$BACKUP_STATE_FILE" ]; then
        mv "$BACKUP_STATE_FILE" "$STATE_FILE"
    else
        rm -f "$STATE_FILE"
    fi
}

# Helper functions
get_alacritty_count() {
    wmctrl -l | grep -i "Alacritty" | wc -l
}

get_alacritty_window_ids() {
    wmctrl -l | grep -i "Alacritty" | awk '{print $1}' | sed 's/0x0*//'
}

get_current_toggle_id() {
    if [ -f "$STATE_FILE" ]; then
        grep "current_toggle_id=" "$STATE_FILE" | cut -d'=' -f2
    fi
}

is_window_minimized() {
    local window_id="$1"
    local hex_id=$(printf "0x%08x" "$window_id" 2>/dev/null)
    if [ -n "$hex_id" ]; then
        local wm_state=$(xprop -id "$hex_id" WM_STATE 2>/dev/null)
        echo "$wm_state" | grep -q "Iconic"
    else
        return 1
    fi
}

is_window_visible() {
    local window_id="$1"
    local hex_id=$(printf "0x%08x" "$window_id" 2>/dev/null)
    if [ -n "$hex_id" ]; then
        local wm_state=$(xprop -id "$hex_id" WM_STATE 2>/dev/null)
        echo "$wm_state" | grep -q "Normal"
    else
        return 1
    fi
}

is_window_active() {
    local window_id="$1"
    local active_window=$(xdotool getactivewindow 2>/dev/null)
    [ "$window_id" = "$active_window" ]
}

wait_for_window_change() {
    sleep 1.5
}

activate_window() {
    local window_id="$1"
    local hex_id=$(printf "0x%08x" "$window_id" 2>/dev/null)
    wmctrl -i -a "$hex_id" 2>/dev/null
    wait_for_window_change
}

@test "COMPLETE CYCLE 1: Initial terminal toggle cycle (launch->minimize->restore)" {
    echo "=== PHASE 1: Complete initial terminal toggle cycle ==="
    
    # STEP 1: Initial super+enter - launch terminal
    echo "STEP 1: Launch terminal (super+enter when no terminals exist)"
    
    # Confirm no terminals exist
    initial_count=$(get_alacritty_count)
    [ "$initial_count" -eq 0 ]
    echo "  ✓ Confirmed no alacritty terminals exist: $initial_count"
    
    # Execute toggle (should launch)
    run "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_for_window_change
    
    # Confirm terminal launched
    final_count=$(get_alacritty_count)
    [ "$final_count" -eq 1 ]
    echo "  ✓ Terminal launched: count $initial_count -> $final_count"
    
    # Get window details
    local window_ids=($(get_alacritty_window_ids))
    local window_id="${window_ids[0]}"
    local decimal_id=$(printf "%d" "0x$window_id" 2>/dev/null)
    echo "  ✓ Window ID: $decimal_id (hex: $window_id)"
    
    # Confirm window is visible
    run is_window_visible "$decimal_id"
    [ "$status" -eq 0 ]
    echo "  ✓ Window is visible (Normal state)"
    
    # Confirm state file tracking
    local stored_id=$(get_current_toggle_id)
    [ "$stored_id" = "$decimal_id" ]
    echo "  ✓ State file tracking window: $stored_id"
    
    # STEP 2: Second super+enter - minimize terminal
    echo "STEP 2: Minimize terminal (super+enter when terminal is active)"
    
    # Ensure terminal is active
    activate_window "$decimal_id"
    
    # Confirm terminal is active
    run is_window_active "$decimal_id"
    [ "$status" -eq 0 ]
    echo "  ✓ Window activated and confirmed active"
    
    # Execute toggle (should minimize)
    run "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_for_window_change
    
    # Confirm terminal minimized
    run is_window_minimized "$decimal_id"
    [ "$status" -eq 0 ]
    echo "  ✓ Window minimized (Iconic state)"
    
    # Confirm still only 1 terminal
    current_count=$(get_alacritty_count)
    [ "$current_count" -eq 1 ]
    echo "  ✓ Terminal count unchanged: $current_count"
    
    # STEP 3: Third super+enter - restore terminal
    echo "STEP 3: Restore terminal (super+enter when terminal is minimized)"
    
    # Execute toggle (should restore)
    run "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_for_window_change
    
    # Confirm terminal restored
    run is_window_visible "$decimal_id"
    [ "$status" -eq 0 ]
    echo "  ✓ Window restored (Normal state)"
    
    # Confirm terminal is active
    run is_window_active "$decimal_id"
    [ "$status" -eq 0 ]
    echo "  ✓ Window is active after restore"
    
    echo "=== PHASE 1 COMPLETED: Initial toggle cycle successful ==="
}

@test "COMPLETE CYCLE 2: New terminal launch and toggle cycle" {
    echo "=== PHASE 2: New terminal and focus shift test ==="
    
    # SETUP: Launch first terminal
    echo "SETUP: Launch first terminal for baseline"
    run "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_for_window_change
    
    local first_window_ids=($(get_alacritty_window_ids))
    local first_window_id="${first_window_ids[0]}"
    local first_decimal_id=$(printf "%d" "0x$first_window_id" 2>/dev/null)
    echo "  ✓ First terminal setup: ID $first_decimal_id"
    
    # STEP 1: Launch new terminal (super+shift+enter)
    echo "STEP 1: Launch new terminal (super+shift+enter)"
    
    # Execute new command
    run "$TERMINAL_TOGGLE" new
    [ "$status" -eq 0 ]
    wait_for_window_change
    
    # Confirm 2 terminals exist
    terminal_count=$(get_alacritty_count)
    [ "$terminal_count" -eq 2 ]
    echo "  ✓ New terminal launched: count 1 -> $terminal_count"
    
    # Get second terminal ID
    local all_window_ids=($(get_alacritty_window_ids))
    local second_window_id=""
    for window in "${all_window_ids[@]}"; do
        local decimal_id=$(printf "%d" "0x$window" 2>/dev/null)
        if [ "$decimal_id" != "$first_decimal_id" ]; then
            second_window_id="$window"
            break
        fi
    done
    
    local second_decimal_id=$(printf "%d" "0x$second_window_id" 2>/dev/null)
    echo "  ✓ Second terminal ID: $second_decimal_id"
    
    # Confirm focus shifted to new terminal
    local stored_id=$(get_current_toggle_id)
    [ "$stored_id" = "$second_decimal_id" ]
    echo "  ✓ Focus shifted to new terminal: state file shows $stored_id"
    
    # STEP 2: Toggle cycle with new terminal (minimize)
    echo "STEP 2: Minimize new terminal"
    
    # Ensure new terminal is active
    activate_window "$second_decimal_id"
    
    # Execute toggle (should minimize new terminal)
    run "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_for_window_change
    
    # Confirm new terminal minimized
    run is_window_minimized "$second_decimal_id"
    [ "$status" -eq 0 ]
    echo "  ✓ New terminal minimized"
    
    # STEP 3: Restore new terminal
    echo "STEP 3: Restore new terminal"
    
    # Execute toggle (should restore new terminal)
    run "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_for_window_change
    
    # Confirm new terminal restored
    run is_window_visible "$second_decimal_id"
    [ "$status" -eq 0 ]
    echo "  ✓ New terminal restored"
    
    # Confirm new terminal is active
    run is_window_active "$second_decimal_id"
    [ "$status" -eq 0 ]
    echo "  ✓ New terminal is active after restore"
    
    echo "=== PHASE 2 COMPLETED: New terminal cycle successful ==="
}

@test "COMPLETE CYCLE 3: Focus switching (Alt+Tab simulation) and toggle cycle" {
    echo "=== PHASE 3: Focus switching and lock behavior test ==="
    
    # SETUP: Launch two terminals
    echo "SETUP: Launch two terminals"
    run "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_for_window_change
    
    run "$TERMINAL_TOGGLE" new
    [ "$status" -eq 0 ]
    wait_for_window_change
    
    # Get both terminal IDs
    local all_window_ids=($(get_alacritty_window_ids))
    [ "${#all_window_ids[@]}" -eq 2 ]
    
    local first_window_id="${all_window_ids[0]}"
    local second_window_id="${all_window_ids[1]}"
    local first_decimal_id=$(printf "%d" "0x$first_window_id" 2>/dev/null)
    local second_decimal_id=$(printf "%d" "0x$second_window_id" 2>/dev/null)
    
    echo "  ✓ Setup complete: Terminal 1=$first_decimal_id, Terminal 2=$second_decimal_id"
    
    # Current focus should be on second terminal (most recent)
    local initial_stored_id=$(get_current_toggle_id)
    [ "$initial_stored_id" = "$second_decimal_id" ]
    echo "  ✓ Initial focus on second terminal: $initial_stored_id"
    
    # STEP 1: Simulate Alt+Tab to first terminal
    echo "STEP 1: Switch focus to first terminal (Alt+Tab simulation)"
    
    activate_window "$first_decimal_id"
    
    # Confirm first terminal is active
    run is_window_active "$first_decimal_id"
    [ "$status" -eq 0 ]
    echo "  ✓ First terminal is now active"
    
    # STEP 2: Toggle should lock onto first terminal and minimize it
    echo "STEP 2: Toggle should lock onto first terminal"
    
    run "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_for_window_change
    
    # Confirm first terminal minimized
    run is_window_minimized "$first_decimal_id"
    [ "$status" -eq 0 ]
    echo "  ✓ First terminal minimized (focus locked)"
    
    # Confirm state updated to track first terminal
    local updated_stored_id=$(get_current_toggle_id)
    [ "$updated_stored_id" = "$first_decimal_id" ]
    echo "  ✓ State locked onto first terminal: $updated_stored_id"
    
    # STEP 3: Restore first terminal
    echo "STEP 3: Restore first terminal"
    
    run "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_for_window_change
    
    # Confirm first terminal restored
    run is_window_visible "$first_decimal_id"
    [ "$status" -eq 0 ]
    echo "  ✓ First terminal restored"
    
    # STEP 4: Switch to second terminal and test lock
    echo "STEP 4: Switch focus to second terminal and test lock"
    
    activate_window "$second_decimal_id"
    
    # Toggle should lock onto second terminal
    run "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_for_window_change
    
    # Confirm second terminal minimized
    run is_window_minimized "$second_decimal_id"
    [ "$status" -eq 0 ]
    echo "  ✓ Second terminal minimized (focus re-locked)"
    
    # Confirm state updated to track second terminal
    local final_stored_id=$(get_current_toggle_id)
    [ "$final_stored_id" = "$second_decimal_id" ]
    echo "  ✓ State re-locked onto second terminal: $final_stored_id"
    
    echo "=== PHASE 3 COMPLETED: Focus switching test successful ==="
}

@test "COMPLETE WORKFLOW: Full end-to-end integration test" {
    echo "=== COMPLETE WORKFLOW: All phases in sequence ==="
    
    # This test runs all phases in sequence to verify complete integration
    
    echo "Phase A: Initial cycle (launch->minimize->restore)"
    
    # Launch
    run "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_for_window_change
    [ "$(get_alacritty_count)" -eq 1 ]
    
    local first_id=$(get_alacritty_window_ids | head -1)
    local first_decimal=$(printf "%d" "0x$first_id" 2>/dev/null)
    
    # Minimize
    activate_window "$first_decimal"
    run "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_for_window_change
    run is_window_minimized "$first_decimal"
    [ "$status" -eq 0 ]
    
    # Restore
    run "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_for_window_change
    run is_window_visible "$first_decimal"
    [ "$status" -eq 0 ]
    
    echo "  ✓ Phase A completed"
    
    echo "Phase B: New terminal and cycle"
    
    # New terminal
    run "$TERMINAL_TOGGLE" new
    [ "$status" -eq 0 ]
    wait_for_window_change
    [ "$(get_alacritty_count)" -eq 2 ]
    
    # Get second terminal
    local all_ids=($(get_alacritty_window_ids))
    local second_id=""
    for id in "${all_ids[@]}"; do
        local decimal=$(printf "%d" "0x$id" 2>/dev/null)
        if [ "$decimal" != "$first_decimal" ]; then
            second_id="$id"
            break
        fi
    done
    local second_decimal=$(printf "%d" "0x$second_id" 2>/dev/null)
    
    # Test cycle with second terminal
    activate_window "$second_decimal"
    run "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_for_window_change
    run is_window_minimized "$second_decimal"
    [ "$status" -eq 0 ]
    
    run "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_for_window_change
    run is_window_visible "$second_decimal"
    [ "$status" -eq 0 ]
    
    echo "  ✓ Phase B completed"
    
    echo "Phase C: Focus switching"
    
    # Switch to first terminal
    activate_window "$first_decimal"
    run "$TERMINAL_TOGGLE" toggle
    [ "$status" -eq 0 ]
    wait_for_window_change
    run is_window_minimized "$first_decimal"
    [ "$status" -eq 0 ]
    [ "$(get_current_toggle_id)" = "$first_decimal" ]
    
    echo "  ✓ Phase C completed"
    
    echo "=== COMPLETE WORKFLOW PASSED: All functionality verified ==="
}