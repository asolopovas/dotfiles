#!/bin/bash

# install-cinnamon-settings.sh
# Script to configure Cinnamon shortcuts to match XMonad configuration

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Check if we're running in Cinnamon
check_desktop_environment() {
    if [[ "$XDG_CURRENT_DESKTOP" != *"Cinnamon"* ]] && [[ "$DESKTOP_SESSION" != *"cinnamon"* ]]; then
        print_warning "This script is designed for Cinnamon desktop environment"
        print_warning "Current desktop: $XDG_CURRENT_DESKTOP"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Function to set a keyboard shortcut
set_keybinding() {
    local name="$1"
    local command="$2"
    local binding="$3"

    print_status "Setting keybinding: $name -> $binding"

    # Create custom keybinding
    gsettings set org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/$name/ name "$name"
    gsettings set org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/$name/ command "$command"
    gsettings set org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/$name/ binding "['$binding']"
}

# Function to add custom keybinding to the list
add_custom_keybinding() {
    local name="$1"
    local current_list=$(gsettings get org.cinnamon.desktop.keybindings custom-list)

    # Remove brackets and quotes, split by comma
    if [[ "$current_list" == "@as []" ]]; then
        new_list="['$name']"
    else
        # Remove the closing bracket and add new item
        new_list=$(echo "$current_list" | sed "s/]$/, '$name']/")
    fi

    gsettings set org.cinnamon.desktop.keybindings custom-list "$new_list"
}

# Function to disable conflicting default shortcuts
disable_default_shortcut() {
    local schema="$1"
    local key="$2"

    print_status "Disabling default shortcut: $schema $key"
    gsettings set "$schema" "$key" "[]"
}

main() {
    print_header "Cinnamon Shortcuts Configuration (XMonad-inspired)"

    # Get the current user's home directory dynamically
    USER_HOME="$(eval echo ~$USER)"

    check_desktop_environment

    # Create applications directory if it doesn't exist
    mkdir -p ~/.local/share/applications

    print_header "Disabling ALL Default Cinnamon Shortcuts"

    # Disable all default WM shortcuts (with error handling)
    gsettings set org.cinnamon.desktop.keybindings.wm switch-to-workspace-1 "[]" 2>/dev/null || true
    gsettings set org.cinnamon.desktop.keybindings.wm switch-to-workspace-2 "[]" 2>/dev/null || true
    gsettings set org.cinnamon.desktop.keybindings.wm switch-to-workspace-3 "[]" 2>/dev/null || true
    gsettings set org.cinnamon.desktop.keybindings.wm switch-to-workspace-4 "[]" 2>/dev/null || true
    gsettings set org.cinnamon.desktop.keybindings.wm switch-to-workspace-5 "[]" 2>/dev/null || true
    gsettings set org.cinnamon.desktop.keybindings.wm switch-to-workspace-6 "[]" 2>/dev/null || true
    gsettings set org.cinnamon.desktop.keybindings.wm switch-to-workspace-7 "[]" 2>/dev/null || true
    gsettings set org.cinnamon.desktop.keybindings.wm switch-to-workspace-8 "[]" 2>/dev/null || true
    gsettings set org.cinnamon.desktop.keybindings.wm move-to-workspace-1 "[]" 2>/dev/null || true
    gsettings set org.cinnamon.desktop.keybindings.wm move-to-workspace-2 "[]" 2>/dev/null || true
    gsettings set org.cinnamon.desktop.keybindings.wm move-to-workspace-3 "[]" 2>/dev/null || true
    gsettings set org.cinnamon.desktop.keybindings.wm move-to-workspace-4 "[]" 2>/dev/null || true
    gsettings set org.cinnamon.desktop.keybindings.wm move-to-workspace-5 "[]" 2>/dev/null || true
    gsettings set org.cinnamon.desktop.keybindings.wm move-to-workspace-6 "[]" 2>/dev/null || true
    gsettings set org.cinnamon.desktop.keybindings.wm move-to-workspace-7 "[]" 2>/dev/null || true
    gsettings set org.cinnamon.desktop.keybindings.wm move-to-workspace-8 "[]" 2>/dev/null || true

    # Disable window management shortcuts (with error handling)
    gsettings set org.cinnamon.desktop.keybindings.wm close "[]" 2>/dev/null || true
    gsettings set org.cinnamon.desktop.keybindings.wm toggle-fullscreen "[]" 2>/dev/null || true
    gsettings set org.cinnamon.desktop.keybindings.wm toggle-maximized "[]" 2>/dev/null || true
    gsettings set org.cinnamon.desktop.keybindings.wm minimize "[]" 2>/dev/null || true
    gsettings set org.cinnamon.desktop.keybindings.wm maximize "[]" 2>/dev/null || true
    gsettings set org.cinnamon.desktop.keybindings.wm unmaximize "[]" 2>/dev/null || true
    gsettings set org.cinnamon.desktop.keybindings.wm switch-to-workspace-left "[]" 2>/dev/null || true
    gsettings set org.cinnamon.desktop.keybindings.wm switch-to-workspace-right "[]" 2>/dev/null || true
    gsettings set org.cinnamon.desktop.keybindings.wm switch-to-workspace-up "[]" 2>/dev/null || true
    gsettings set org.cinnamon.desktop.keybindings.wm switch-to-workspace-down "[]" 2>/dev/null || true
    gsettings set org.cinnamon.desktop.keybindings.wm move-to-workspace-left "[]" 2>/dev/null || true
    gsettings set org.cinnamon.desktop.keybindings.wm move-to-workspace-right "[]" 2>/dev/null || true
    gsettings set org.cinnamon.desktop.keybindings.wm move-to-workspace-up "[]" 2>/dev/null || true
    gsettings set org.cinnamon.desktop.keybindings.wm move-to-workspace-down "[]" 2>/dev/null || true
    gsettings set org.cinnamon.desktop.keybindings.wm panel-run-dialog "[]" 2>/dev/null || true
    # Keep Alt+Tab functionality - DO NOT disable these, restore if needed
    gsettings set org.cinnamon.desktop.keybindings.wm switch-applications "['<Alt>Tab']" 2>/dev/null || true
    gsettings set org.cinnamon.desktop.keybindings.wm switch-applications-backward "['<Shift><Alt>Tab']" 2>/dev/null || true
    gsettings set org.cinnamon.desktop.keybindings.wm switch-windows "['<Alt>Tab']" 2>/dev/null || true
    gsettings set org.cinnamon.desktop.keybindings.wm switch-windows-backward "['<Shift><Alt>Tab']" 2>/dev/null || true

    # Disable media key shortcuts that might conflict (with error handling)
    gsettings set org.cinnamon.desktop.keybindings.media-keys terminal "[]" 2>/dev/null || true
    gsettings set org.cinnamon.desktop.keybindings.media-keys home "[]" 2>/dev/null || true
    gsettings set org.cinnamon.desktop.keybindings.media-keys search "[]" 2>/dev/null || true
    gsettings set org.cinnamon.desktop.keybindings.media-keys screensaver "[]" 2>/dev/null || true

    # Disable Cinnamon specific shortcuts (with error handling)
    gsettings set org.cinnamon.desktop.keybindings looking-glass-keybinding "[]" 2>/dev/null || true
    gsettings set org.cinnamon.desktop.keybindings.wm show-desktop "[]" 2>/dev/null || true

    # Clear any existing Super+L/lock screen bindings in all possible schemas
    gsettings set org.gnome.settings-daemon.plugins.media-keys screensaver "[]" 2>/dev/null || true
    gsettings set org.cinnamon.settings-daemon.plugins.media-keys screensaver "[]" 2>/dev/null || true

    print_header "Configuring Window Management Shortcuts"

    # Window management (Super key = Windows key)
    set_keybinding "close-window" "wmctrl -c :ACTIVE:" "<Super>q"
    add_custom_keybinding "close-window"

    # Window snapping (mod+hjkl)
    set_keybinding "snap-left" "${USER_HOME}/.local/bin/snap-window left" "<Super>h"
    add_custom_keybinding "snap-left"

    set_keybinding "snap-up" "${USER_HOME}/.local/bin/snap-window up" "<Super>k"
    add_custom_keybinding "snap-up"

    set_keybinding "snap-down" "${USER_HOME}/.local/bin/snap-window down" "<Super>j"
    add_custom_keybinding "snap-down"

    set_keybinding "snap-right" "${USER_HOME}/.local/bin/snap-window right" "<Super>l"
    add_custom_keybinding "snap-right"

    # Toggle fullscreen
    gsettings set org.cinnamon.desktop.keybindings.wm toggle-fullscreen "['<Super>f']"

    print_header "Configuring Application Shortcuts"

    # Terminal toggle (minimize/maximize active terminal)
    set_keybinding "terminal-toggle" "${USER_HOME}/.local/bin/toggle-terminal-window" "<Super>Return"
    add_custom_keybinding "terminal-toggle"

    # Application launcher (rofi equivalent - using Cinnamon's menu)
    set_keybinding "app-launcher" "cinnamon-launcher" "<Super>d"
    add_custom_keybinding "app-launcher"

    # Browser (moved from Super+c to avoid conflict)
    set_keybinding "browser" "brave-browser --no-default-browser-check --enable-features=WebUIDarkMode --force-dark-mode" "<Super><Shift>c"
    add_custom_keybinding "browser"

    # File browser
    set_keybinding "file-browser" "thunar" "<Super>x"
    add_custom_keybinding "file-browser"

    # Scratchpad terminal
    set_keybinding "scratchpad-terminal" "alacritty -t scratchpad" "<Super><Shift>Return"
    add_custom_keybinding "scratchpad-terminal"

    # Music player (Tauon - Super+m)
    set_keybinding "music-player" "flatpak run com.github.taiko2k.tauonmb" "<Super>m"
    add_custom_keybinding "music-player"

    # Firefox scratchpad (Super+b)
    set_keybinding "firefox-scratchpad" "firefox --class='FirefoxScratchpad'" "<Super>b"
    add_custom_keybinding "firefox-scratchpad"

    # Secondary browser (Super+c - kept as main browser)
    set_keybinding "browser-main" "brave-browser --no-default-browser-check --enable-features=WebUIDarkMode --force-dark-mode" "<Super>c"
    add_custom_keybinding "browser-main"

    # Additional XMonad shortcuts
    set_keybinding "focus-master" "wmctrl -a :ACTIVE:" "<Super>s"  # Focus master (limited in Cinnamon)
    add_custom_keybinding "focus-master"

    set_keybinding "sysact" "gnome-session-quit --power-off" "<Super>0"  # System actions
    add_custom_keybinding "sysact"

    set_keybinding "fzf-thunar" "thunar" "<Super>p"  # File browser with fuzzy search
    add_custom_keybinding "fzf-thunar"

    set_keybinding "fzf-code" "code ." "<Super>o"  # Code editor
    add_custom_keybinding "fzf-code"

    set_keybinding "fzf-alacritty" "alacritty" "<Super><Shift>p"  # Terminal fuzzy launcher
    add_custom_keybinding "fzf-alacritty"

    set_keybinding "su-dmenu" "gksu dmenu_run" "<Super><Shift>d"  # Root dmenu
    add_custom_keybinding "su-dmenu"

    set_keybinding "pcmanfm-search" "catfish" "<Super><Shift>x"  # File search
    add_custom_keybinding "pcmanfm-search"

    print_header "Configuring Media Key Shortcuts"

    # Volume controls
    gsettings set org.cinnamon.desktop.keybindings.media-keys volume-down "['XF86AudioLowerVolume']"
    gsettings set org.cinnamon.desktop.keybindings.media-keys volume-up "['XF86AudioRaiseVolume']"
    gsettings set org.cinnamon.desktop.keybindings.media-keys volume-mute "['XF86AudioMute']"

    # Media player controls
    gsettings set org.cinnamon.desktop.keybindings.media-keys play "['XF86AudioPlay']"
    gsettings set org.cinnamon.desktop.keybindings.media-keys stop "['XF86AudioStop']"
    gsettings set org.cinnamon.desktop.keybindings.media-keys previous "['XF86AudioPrev']"
    gsettings set org.cinnamon.desktop.keybindings.media-keys next "['XF86AudioNext']"

    # Brightness controls
    gsettings set org.cinnamon.desktop.keybindings.media-keys screen-brightness-up "['XF86MonBrightnessUp']"
    gsettings set org.cinnamon.desktop.keybindings.media-keys screen-brightness-down "['XF86MonBrightnessDown']"

    # Screenshot
    gsettings set org.cinnamon.desktop.keybindings.media-keys screenshot "['Print']"
    set_keybinding "screenshot-gui" "flameshot gui" "Print"
    add_custom_keybinding "screenshot-gui"

    print_header "Configuring Workspace Shortcuts"

    # Re-enable ONLY our custom workspace shortcuts (1-8, matching XMonad's actual workspace count)
    for i in {1..8}; do
        gsettings set org.cinnamon.desktop.keybindings.wm "switch-to-workspace-$i" "['<Super>$i']"
        gsettings set org.cinnamon.desktop.keybindings.wm "move-to-workspace-$i" "['<Super><Shift>$i']"
    done

    # Workspace navigation with arrow keys (re-enable after clearing)
    gsettings set org.cinnamon.desktop.keybindings.wm switch-to-workspace-left "['<Super>Left']"
    gsettings set org.cinnamon.desktop.keybindings.wm switch-to-workspace-right "['<Super>Right']"
    gsettings set org.cinnamon.desktop.keybindings.wm move-to-workspace-left "['<Super><Shift>Left']"
    gsettings set org.cinnamon.desktop.keybindings.wm move-to-workspace-right "['<Super><Shift>Right']"

    print_header "Configuring Additional Shortcuts"

    # System monitor (similar to stacer)
    set_keybinding "system-monitor" "gnome-system-monitor" "F8"
    add_custom_keybinding "system-monitor"

    # Calculator
    set_keybinding "calculator" "gnome-calculator" "XF86Calculator"
    add_custom_keybinding "calculator"

    # Audio control (pavucontrol)
    set_keybinding "audio-control" "pavucontrol" "XF86Launch6"
    add_custom_keybinding "audio-control"

    # Chat application placeholder (F7)
    set_keybinding "chat-app" "telegram-desktop" "F7"
    add_custom_keybinding "chat-app"

    print_header "Configuring Window Tiling Behavior"

    # Enable window snapping and tiling
    gsettings set org.cinnamon.desktop.wm.preferences resize-with-right-button true
    gsettings set org.cinnamon.desktop.wm.preferences mouse-button-modifier '<Super>'

    # Configure window focus behavior
    gsettings set org.cinnamon.desktop.wm.preferences focus-mode 'click'
    gsettings set org.cinnamon.desktop.wm.preferences auto-raise false

    # Window effects and animations
    gsettings set org.cinnamon.desktop.wm.preferences theme 'Mint-Y-Dark'

    print_header "Creating Custom Scripts for Advanced Features"

    # Create terminal toggle script (handle terminal launching and toggling)
    cat > ~/.local/bin/toggle-terminal-window << 'EOF'
#!/bin/bash
# Toggle terminal: launch if none exist, focus if exists but not active, toggle maximize if active

# Debug logging (uncomment to debug)
# echo "$(date): toggle-terminal-window called" >> /tmp/terminal-toggle.log

if command -v wmctrl &> /dev/null && command -v xdotool &> /dev/null; then
    # Get current active window (in decimal format)
    active_window_dec=$(xdotool getactivewindow 2>/dev/null)

    # Convert to hexadecimal format for wmctrl comparison
    active_window_hex=$(printf "0x%08x" "$active_window_dec" 2>/dev/null)

    # Find all terminal windows (returns hex format)
    terminal_windows=$(wmctrl -l -x | grep -i "alacritty\|gnome-terminal\|terminal\|konsole" | awk '{print $1}')

    # Debug logging
    # echo "Active window: $active_window_dec ($active_window_hex)" >> /tmp/terminal-toggle.log
    # echo "Terminal windows: $terminal_windows" >> /tmp/terminal-toggle.log

    if [ -z "$terminal_windows" ]; then
        # No terminals exist - launch new one
        alacritty & disown
        # echo "Launched new terminal" >> /tmp/terminal-toggle.log
        exit 0
    fi

    # Check if active window is a terminal (compare hex formats)
    if [ -n "$active_window_hex" ]; then
        if echo "$terminal_windows" | grep -q "$active_window_hex"; then
            # Active window is a terminal - toggle its maximize state
            wmctrl -i -r "$active_window_dec" -b toggle,maximized_vert,maximized_horz
            # echo "Toggled maximize for active terminal $active_window_hex" >> /tmp/terminal-toggle.log
            exit 0
        fi
    fi

    # Active window is not a terminal, or no active window
    # Focus the first terminal found
    first_terminal=$(echo "$terminal_windows" | head -n1)
    wmctrl -i -a "$first_terminal"
    # echo "Focused existing terminal $first_terminal" >> /tmp/terminal-toggle.log
else
    # Fallback: just launch terminal
    alacritty & disown
    # echo "Fallback: launched terminal" >> /tmp/terminal-toggle.log
fi
EOF
    chmod +x ~/.local/bin/toggle-terminal-window

    # Install 4-column grid snap-window script from dotfiles
    if [ -f "${HOME}/dotfiles/scripts/snap-window" ]; then
        cp "${HOME}/dotfiles/scripts/snap-window" ~/.local/bin/snap-window
        chmod +x ~/.local/bin/snap-window
        print_status "Installed 4-column grid snap-window script"
    else
        print_warning "snap-window script not found in dotfiles/scripts/"
    fi

    # Create a simple window cycling script (since Cinnamon's alt-tab is different)
    cat > ~/.local/bin/cinnamon-cycle-windows << 'EOF'
#!/bin/bash
# Simple window cycling for Cinnamon
if command -v wmctrl &> /dev/null; then
    current_window=$(xdotool getactivewindow)
    window_list=$(wmctrl -l | awk '{print $1}' | grep -v $current_window)
    if [ -n "$window_list" ]; then
        next_window=$(echo "$window_list" | head -n1)
        wmctrl -i -a $next_window
    fi
else
    # Fallback to Alt+Tab
    xdotool key alt+Tab
fi
EOF
    chmod +x ~/.local/bin/cinnamon-cycle-windows

    # Create floating window toggle script
    cat > ~/.local/bin/toggle-window-float << 'EOF'
#!/bin/bash
# Toggle window always-on-top (closest to floating in tiling WM)
if command -v wmctrl &> /dev/null; then
    active_window=$(xdotool getactivewindow)
    wmctrl -i -b toggle,above $active_window
fi
EOF
    chmod +x ~/.local/bin/toggle-window-float

    set_keybinding "toggle-float" "${USER_HOME}/.local/bin/toggle-window-float" "<Super>t"
    add_custom_keybinding "toggle-float"

    print_header "Installing Required Dependencies"

    # Check and install required tools
    REQUIRED_TOOLS=("wmctrl" "xdotool" "flameshot" "alacritty" "thunar" "xprop" "xdpyinfo")
    MISSING_TOOLS=()

    for tool in "${REQUIRED_TOOLS[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            MISSING_TOOLS+=("$tool")
        fi
    done

    if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
        print_warning "Missing tools: ${MISSING_TOOLS[*]}"
        print_status "Install with: sudo apt install ${MISSING_TOOLS[*]}"

        read -p "Install missing tools now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo apt update && sudo apt install -y "${MISSING_TOOLS[@]}"
        fi
    fi

    print_header "Configuration Complete!"

    print_status "Shortcuts configured:"
    echo "  • Super+Return: Toggle terminal (minimize/maximize active or open new)"
    echo "  • Super+d: Application launcher"
    echo "  • Super+c: Browser (Brave)"
    echo "  • Super+b: Firefox scratchpad"
    echo "  • Super+m: Music player (Tauon)"
    echo "  • Super+x: File manager (Thunar)"
    echo "  • Super+p: File browser (fuzzy)"
    echo "  • Super+o: Code editor"
    echo "  • Super+s: Focus master window"
    echo "  • Super+0: System actions/power menu"
    echo "  • Super+h: Snap window left (4-column grid aware)"
    echo "  • Super+j: Snap window down (4-column grid aware)"
    echo "  • Super+k: Snap window up (4-column grid aware)"
    echo "  • Super+l: Snap window right (4-column grid aware)"
    echo "  • Super+q: Close window"
    echo "  • Super+f: Toggle fullscreen"
    echo "  • Super+t: Toggle window always-on-top"
    echo "  • Super+Shift+Return: Scratchpad terminal"
    echo "  • Super+Shift+d: Root launcher"
    echo "  • Super+Shift+p: Terminal launcher"
    echo "  • Super+Shift+x: File search (catfish)"
    echo "  • Super+1-8: Switch to workspace"
    echo "  • Super+Shift+1-8: Move window to workspace"
    echo "  • Super+Left/Right: Switch to previous/next workspace"
    echo "  • Super+Shift+Left/Right: Move window to previous/next workspace"
    echo "  • F7: Chat application"
    echo "  • F8: System monitor"
    echo "  • Print: Screenshot"
    echo "  • Alt+Tab: Switch between windows (preserved)"
    echo "  • Media keys: Volume, brightness, playback controls"

    print_warning "Note: Some advanced XMonad features cannot be replicated in Cinnamon:"
    echo "  • True tiling window management"
    echo "  • Master/stack layout concepts"
    echo "  • Advanced window swapping"
    echo "  • Scratchpad functionality (using regular windows instead)"

    print_status "You may need to log out and log back in for all changes to take effect."
    print_status "You can customize further through Cinnamon Settings > Keyboard > Shortcuts"
}

# Run main function
main "$@"
