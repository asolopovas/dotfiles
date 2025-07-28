#!/usr/bin/env bats

# Terminal toggle dual-agent test

setup() {
    TERMINAL_TOGGLE="/home/andrius/dotfiles/scripts/terminal-toggle"
    pkill -f alacritty 2>/dev/null || true
    rm -f ~/.cache/terminal-toggle-state
    sleep 1
    
    if ! command -v wmctrl &> /dev/null || ! command -v xdotool &> /dev/null; then
        skip "Required tools not available"
    fi
}

teardown() {
    pkill -f alacritty 2>/dev/null || true
    sleep 0.5
}

count_terminals() { wmctrl -l | grep -i "Alacritty" | wc -l; }
get_terminal_ids() { wmctrl -l | grep -i "Alacritty" | awk '{print $1}'; }
is_minimized() {
    local hex_id=$(printf "0x%08x" "$(printf "%d" "$1" 2>/dev/null)" 2>/dev/null)
    local state=$(xprop -id "$hex_id" WM_STATE 2>/dev/null | grep -o "Iconic\|Normal")
    [ "$state" = "Iconic" ]
}

execute_toggle() {
    echo "OPERATOR: $1"
    $2 &
    sleep 2
}

log_state() {
    local action="$1"
    local terminal_count=$(count_terminals)
    local state_content=""
    [ -f ~/.cache/terminal-toggle-state ] && state_content=$(cat ~/.cache/terminal-toggle-state)
    local active_window=$(xdotool getactivewindow 2>/dev/null || echo "none")
    local terminal_ids=$(get_terminal_ids | tr '\n' ',' | sed 's/,$//')
    
    echo "=== $action ==="
    echo "Terminal count: $terminal_count"
    echo "Terminal IDs: [$terminal_ids]"
    echo "Active window: $active_window"
    echo "State file:"
    echo "$state_content"
    echo "===================="
}

wait_for_terminal_change() {
    local expected_count="$1"
    local max_attempts=20
    local attempts=0
    
    while [ $attempts -lt $max_attempts ]; do
        local current_count=$(count_terminals)
        if [ "$current_count" -eq "$expected_count" ]; then
            echo "OBSERVER: Terminal count reached $expected_count after $attempts attempts"
            return 0
        fi
        sleep 0.2
        ((attempts++))
    done
    
    echo "OBSERVER: TIMEOUT - Expected $expected_count terminals, got $(count_terminals)"
    return 1
}

wait_for_window_state_change() {
    local window_id="$1"
    local expected_state="$2"  # "minimized" or "visible"
    local max_attempts=15
    local attempts=0
    
    while [ $attempts -lt $max_attempts ]; do
        if [ "$expected_state" = "minimized" ]; then
            if is_minimized "$window_id"; then
                echo "OBSERVER: Window $window_id minimized after $attempts attempts"
                return 0
            fi
        else
            if ! is_minimized "$window_id"; then
                echo "OBSERVER: Window $window_id visible after $attempts attempts"
                return 0
            fi
        fi
        sleep 0.2
        ((attempts++))
    done
    
    echo "OBSERVER: TIMEOUT - Window $window_id did not reach $expected_state state"
    return 1
}

simulate_hotkey() {
    local action="$1"
    local key="$2"
    local expected_terminal_count="$3"
    
    echo "OPERATOR: Simulating $action ($key)"
    local before_count=$(count_terminals)
    echo "OBSERVER: Before hotkey - terminals: $before_count"
    
    xdotool key "$key"
    
    if [ -n "$expected_terminal_count" ]; then
        wait_for_terminal_change "$expected_terminal_count" || return 1
    else
        sleep 1
    fi
    
    log_state "$action"
}

@test "Terminal toggle hotkey simulation with logging" {
    echo "Terminal toggle hotkey simulation: Real Super+Enter and Super+Shift+Enter"
    
    # Initial state
    log_state "INITIAL STATE"
    [ "$(count_terminals)" -eq 0 ]
    
    # Phase 1: Super+Enter (first terminal)
    simulate_hotkey "Super+Enter (first terminal)" "super+Return" 1
    [ "$(count_terminals)" -eq 1 ]
    
    local first_terminal=$(get_terminal_ids | head -1)
    echo "OBSERVER: First terminal ID: $first_terminal"
    
    # Phase 2: Super+Enter again (minimize first terminal)
    simulate_hotkey "Super+Enter (minimize first)" "super+Return" 1
    wait_for_window_state_change "$first_terminal" "minimized" || return 1
    
    # Phase 3: Super+Enter again (restore first terminal)
    simulate_hotkey "Super+Enter (restore first)" "super+Return" 1
    wait_for_window_state_change "$first_terminal" "visible" || return 1
    
    # Phase 4: Super+Shift+Enter (launch second terminal)
    simulate_hotkey "Super+Shift+Enter (second terminal)" "super+shift+Return" 2
    [ "$(count_terminals)" -eq 2 ]
    
    local all_windows=($(get_terminal_ids))
    local second_terminal=""
    for window in "${all_windows[@]}"; do
        [ "$window" != "$first_terminal" ] && second_terminal="$window" && break
    done
    echo "OBSERVER: Second terminal ID: $second_terminal"
    
    # Phase 5: Super+Enter (should minimize SECOND terminal, not first)
    echo "OBSERVER: About to test critical locking - first: $first_terminal, second: $second_terminal"
    simulate_hotkey "Super+Enter (minimize second)" "super+Return" 2
    
    # Wait for state change and then check
    sleep 1
    wait_for_window_state_change "$second_terminal" "minimized" || {
        echo "OBSERVER: Second terminal did not minimize - checking if first was affected instead"
        if is_minimized "$first_terminal"; then
            echo "BUG: First terminal was minimized when second should be affected (locking failure)"
            return 1
        fi
        echo "OBSERVER: Neither terminal minimized - possible timing issue"
        return 1
    }
    
    # Verify first terminal remained visible
    ! is_minimized "$first_terminal" || {
        echo "BUG: First terminal was minimized when second should be affected (locking failure)"
        return 1
    }
    
    echo "OBSERVER: Correct behavior - First: VISIBLE, Second: MINIMIZED"
    
    # Phase 6: Super+Enter again (should restore SECOND terminal)
    simulate_hotkey "Super+Enter (restore second)" "super+Return" 2
    wait_for_window_state_change "$second_terminal" "visible" || return 1
    
    # Final verification
    ! is_minimized "$second_terminal" || return 1
    ! is_minimized "$first_terminal" || return 1
    
    echo "SUCCESS: Hotkey locking mechanism working correctly"
}