#!/usr/bin/env bats

# Terminal toggle dual-agent test

setup() {
    TERMINAL_TOGGLE="/home/andrius/dotfiles/scripts/ui-terminal-toggle"
    # Use make command to kill alacritty processes
    make -C /home/andrius/dotfiles kill-alacritty >/dev/null 2>&1
    # Verify no ALACRITTY terminals remain
    local alacritty_count=$(wmctrl -l | grep -c "Alacritty" || echo "0")
    if [ "$alacritty_count" -ne 0 ]; then
        echo "ERROR: Alacritty windows still exist after cleanup"
        wmctrl -l | grep "Alacritty"
        exit 1
    fi
    rm -f ~/.cache/ui-terminal-toggle-state
    
    if ! command -v wmctrl &> /dev/null || ! command -v xdotool &> /dev/null; then
        skip "Required tools not available"
    fi
}

teardown() {
    pkill -f alacritty 2>/dev/null || true
    sleep 0.5
}

count_terminals() { wmctrl -l | grep "Alacritty" | wc -l; }
get_terminal_ids() { wmctrl -l | grep "Alacritty" | awk '{print $1}'; }
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

press_and_log() {
    local hotkey="$1"
    local description="$2"
    local timestamp=$(date +"%H%M%S")
    local logfile="$HOME/dotfiles/tmp/hotkey-${timestamp}-${description// /-}.log"
    
    echo "HOTKEY: $description ($hotkey)"
    xdotool key "$hotkey"
    sleep 1
    
    # Create comprehensive state log
    {
        echo "=== HOTKEY ANALYSIS: $description ==="
        echo "Timestamp: $(date)"
        echo "Hotkey pressed: $hotkey"
        echo ""
        
        echo "TERMINAL COUNT: $(count_terminals)"
        echo "TERMINAL IDs: $(get_terminal_ids | tr '\n' ',' | sed 's/,$//')"
        echo "ACTIVE WINDOW: $(xdotool getactivewindow 2>/dev/null || echo 'none') (decimal)"
        echo ""
        
        echo "TERMINAL STATES:"
        if [ "$(count_terminals)" -gt 0 ]; then
            get_terminal_ids | while read -r term_id; do
                local decimal_id=$(printf "%d" "$term_id" 2>/dev/null)
                local state="VISIBLE"
                is_minimized "$decimal_id" && state="MINIMIZED"
                echo "  $term_id (decimal: $decimal_id) = $state"
            done
        else
            echo "  No terminals found"
        fi
        echo ""
        
        echo "STATE FILE:"
        if [ -f ~/.cache/ui-terminal-toggle-state ]; then
            cat ~/.cache/ui-terminal-toggle-state
        else
            echo "  No state file found"
        fi
        echo ""
        
        echo "WINDOW LIST:"
        wmctrl -l | grep -i alacritty || echo "  No alacritty windows"
        echo "================================"
    } > "$logfile"
    
    echo "State logged to: $logfile"
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

test_script_call() {
    local cmd="$1"
    local description="$2"
    echo "TESTING: $description"
    echo "COMMAND: $cmd"
    eval "$cmd" &
    sleep 2
    echo "RESULT: Terminal count = $(count_terminals)"
}

diagnose_hotkey_config() {
    echo "=== HOTKEY CONFIGURATION DIAGNOSIS ==="
    echo "ui-terminal-toggle command:"
    gsettings get org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/ui-terminal-toggle/ command 2>/dev/null || echo "Not found"
    echo "ui-terminal-toggle binding:"
    gsettings get org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/ui-terminal-toggle/ binding 2>/dev/null || echo "Not found"
    echo ""
    echo "terminal-new command:"
    gsettings get org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/terminal-new/ command 2>/dev/null || echo "Not found"
    echo "terminal-new binding:"
    gsettings get org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/terminal-new/ binding 2>/dev/null || echo "Not found"
    echo ""
    echo "Script locations:"
    ls -la /home/andrius/.local/bin/ui-terminal-toggle 2>/dev/null || echo "~/.local/bin/ui-terminal-toggle: Not found"
    ls -la /home/andrius/dotfiles/scripts/ui-terminal-toggle 2>/dev/null || echo "~/dotfiles/scripts/ui-terminal-toggle: Not found"
    echo "=================================="
}

manual_step() {
    local step_num="$1"
    local key="$2" 
    local description="$3"
    local expected="$4"
    
    echo "=== STEP $step_num ==="
    echo "KEY TO PRESS: $key"
    echo "ACTION: $description"
    echo "EXPECTED: $expected"
    echo ""
    echo "Press ENTER to execute this step..."
    read -r
    
    if [ "$key" != "manual" ]; then
        xdotool key "$key"
        sleep 2
    else
        # Manual action - execute direct script call
        $TERMINAL_TOGGLE toggle &
        sleep 2
    fi
    
    # Log current state
    local timestamp=$(date +"%H%M%S")
    local logfile="$HOME/dotfiles/tmp/manual-step-${step_num}-${timestamp}.log"
    
    {
        echo "=== MANUAL STEP $step_num: $description ==="
        echo "Key pressed: $key"
        echo "Expected: $expected"
        echo "Timestamp: $(date)"
        echo ""
        echo "TERMINAL COUNT: $(count_terminals)"
        echo "ACTIVE WINDOW: $(xdotool getactivewindow 2>/dev/null) (decimal)"
        echo ""
        echo "TERMINAL IDs:"
        get_terminal_ids | while read -r term_id; do
            local decimal_id=$(printf "%d" "$term_id" 2>/dev/null)
            local state="VISIBLE"
            is_minimized "$decimal_id" && state="MINIMIZED"
            echo "  $term_id (decimal: $decimal_id) = $state"
        done
        echo ""
        echo "STATE FILE:"
        if [ -f ~/.cache/ui-terminal-toggle-state ]; then
            cat ~/.cache/ui-terminal-toggle-state
        else
            echo "  No state file exists"
        fi
        echo "================================"
    } > "$logfile"
    
    echo "State logged to: $logfile"
    echo "ACTUAL RESULT: Please confirm what happened"
    echo ""
}

@test "Manual step-by-step focus diagnosis" {
    mkdir -p "$HOME/dotfiles/tmp"
    rm -f ~/.cache/ui-terminal-toggle-state
    
    manual_step "1" "super+Return" "Launch first terminal" "One Alacritty window opens and becomes active"
    
    # Step 1 failed, try direct script call
    manual_step "2" "manual" "Direct script call - ui-terminal-toggle toggle" "One Alacritty window opens via direct script"
    echo "=== SETUP: Create two terminals with direct script calls ==="
    execute_toggle "Launch first terminal" "$TERMINAL_TOGGLE toggle"
    [ "$(count_terminals)" -eq 1 ]
    local first=$(get_terminal_ids | head -1)
    press_and_log "state_after_first" "after first terminal launch"
    
    execute_toggle "Launch second terminal" "$TERMINAL_TOGGLE new"
    [ "$(count_terminals)" -eq 2 ]
    local second=$(get_terminal_ids | tail -1)
    press_and_log "state_after_second" "after second terminal launch"
    
    # Minimize second terminal (most recent should be affected)
    execute_toggle "Minimize second terminal" "$TERMINAL_TOGGLE toggle"
    is_minimized "$(printf "%d" "$second")" || {
        echo "FAIL: Second terminal should be minimized"
        return 1
    }
    press_and_log "state_after_minimize" "after minimizing second terminal"
    
    echo "=== THOROUGH ALT+TAB FOCUS TESTING ==="
    
    # Step 1: Explicitly focus first terminal
    echo "STEP 1: Manual focus to first terminal"
    wmctrl -i -a "$first"
    sleep 1
    press_and_log "manual_focus_first" "manual focus first terminal"
    local active_after_manual=$(xdotool getactivewindow 2>/dev/null)
    
    [ "$active_after_manual" = "$(printf "%d" "$first")" ] || {
        echo "FAIL: Could not manually focus first terminal"
        echo "Expected: $(printf "%d" "$first"), Got: $active_after_manual"
        return 1
    }
    echo "CONFIRMED: First terminal manually focused"
    
    # Step 2: Test Alt+Tab switching
    echo "STEP 2: Alt+Tab focus switching"
    press_and_log "alt+Tab" "alt tab focus switch"
    local active_after_alttab=$(xdotool getactivewindow 2>/dev/null)
    
    # Step 3: Check state file update
    echo "STEP 3: State file focus tracking verification"
    source ~/.cache/ui-terminal-toggle-state
    local state_current_id="$current_toggle_id"
    echo "OBSERVER: Active window after Alt+Tab: $active_after_alttab"
    echo "OBSERVER: State file current_toggle_id: $state_current_id"
    echo "OBSERVER: First terminal: $(printf "%d" "$first")"
    echo "OBSERVER: Second terminal: $(printf "%d" "$second")"
    
    # Step 4: Test terminal response to focus
    echo "STEP 4: Terminal toggle response to current focus"
    execute_toggle "Toggle after Alt+Tab" "$TERMINAL_TOGGLE toggle"
    press_and_log "toggle_after_alttab" "toggle after alt tab focus switch"
    
    # Step 5: Comprehensive analysis
    echo "STEP 5: Final state analysis"
    local first_final="VISIBLE"; is_minimized "$(printf "%d" "$first")" && first_final="MINIMIZED"
    local second_final="VISIBLE"; is_minimized "$(printf "%d" "$second")" && second_final="MINIMIZED"
    
    echo "THOROUGH ANALYSIS RESULTS:"
    echo "  Manual focus worked: $([ "$active_after_manual" = "$(printf "%d" "$first")" ] && echo "YES" || echo "NO")"
    echo "  Alt+Tab switched focus: $([ "$active_after_alttab" != "$active_after_manual" ] && echo "YES" || echo "NO")"
    echo "  State file updated: $([ "$state_current_id" = "$active_after_alttab" ] && echo "YES" || echo "NO")"
    echo "  First terminal final: $first_final"
    echo "  Second terminal final: $second_final"
    
    # Determine success/failure with specific diagnostics
    if [ "$active_after_alttab" = "$(printf "%d" "$first")" ] && [ "$first_final" = "MINIMIZED" ]; then
        echo "SUCCESS: Alt+Tab focus detection working - affected first terminal correctly"
    elif [ "$active_after_alttab" = "$(printf "%d" "$second")" ] && [ "$second_final" = "VISIBLE" ]; then
        echo "SUCCESS: Alt+Tab focus detection working - affected second terminal correctly"
    elif [ "$state_current_id" != "$active_after_alttab" ]; then
        echo "FAIL: State file not tracking Alt+Tab focus changes"
        echo "FIX: Add check_and_update_focus() at start of toggle_terminal() function"
        return 1
    else
        echo "PARTIAL: Alt+Tab behavior unclear - check logs for detailed analysis"
        echo "Active: $active_after_alttab, State: $state_current_id"
    fi
    
    echo "=== THOROUGH ALT+TAB TEST COMPLETE ==="
    echo "Log files created in ~/dotfiles/tmp/ for detailed analysis"
}