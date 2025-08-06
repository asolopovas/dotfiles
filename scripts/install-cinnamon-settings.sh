#!/bin/bash
# Cinnamon Desktop Configuration Script
# XMonad-inspired window management for Cinnamon
set -e

#============================================================================
# CONSTANTS AND CONFIGURATION
#============================================================================

# Color constants for output formatting
readonly G='\033[0;32m' Y='\033[1;33m' R='\033[0;31m' B='\033[0;34m' NC='\033[0m'

# Directory paths
readonly USER_HOME="$(eval echo ~$USER)"
readonly SCRIPTS_DIR="${HOME}/dotfiles/scripts"
readonly LOCAL_BIN="${HOME}/.local/bin"

# Dependencies to install
readonly REQUIRED_PACKAGES=(xdotool wmctrl x11-xserver-utils)

# Scripts to link
readonly SCRIPTS_TO_LINK=(
    "snap-window:snap-window"
    "terminal-toggle:terminal-toggle"
)

#============================================================================
# UTILITY FUNCTIONS
#============================================================================

# Logging functions
log() { echo -e "${G}[INFO]${NC} $1"; }
warn() { echo -e "${Y}[WARN]${NC} $1"; }
err() { echo -e "${R}[ERROR]${NC} $1"; }
header() { echo -e "${B}=== $1 ===${NC}"; }

# Environment validation
check_desktop_environment() {
    [[ "$XDG_CURRENT_DESKTOP" != *"Cinnamon"* ]] && [[ "$DESKTOP_SESSION" != *"cinnamon"* ]] && {
        warn "Not running Cinnamon desktop"
        read -p "Continue? (y/N): " -n1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
    }
}

# Keybinding management functions
set_custom_key() {
    local name="$1" cmd="$2" key="$3"
    local base_path="org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/$name/"

    gsettings set "${base_path}" name "$name"
    gsettings set "${base_path}" command "$cmd"
    gsettings set "${base_path}" binding "['$key']"

    # Add to custom list
    local list=$(gsettings get org.cinnamon.desktop.keybindings custom-list)
    if [[ "$list" == "@as []" ]]; then
        list="['$name']"
    else
        list=$(echo "$list" | sed "s/]$/, '$name']/")
    fi
    gsettings set org.cinnamon.desktop.keybindings custom-list "$list"
}

disable_key() {
    gsettings set "$1" "$2" "[]" 2>/dev/null || true
}

#============================================================================
# CONFIGURATION DATA
#============================================================================

# Keys to disable in each schema
readonly WM_KEYS_TO_DISABLE=(
    close toggle-fullscreen toggle-maximized minimize maximize unmaximize
    switch-to-workspace-{left,right,up,down} move-to-workspace-{left,right,up,down}
    panel-run-dialog show-desktop
)

readonly MEDIA_KEYS_TO_DISABLE=(terminal home search screensaver)

# Window management keybindings
readonly -A WINDOW_MGMT_KEYS=(
    ["close-window"]="wmctrl -c :ACTIVE::<Super>q"
    ["close-all-windows"]="wmctrl -c :ALL::<Super><Shift>q"
    ["focus-master"]="wmctrl -a :SELECT::<Super>s"
    ["swap-window-down"]="xdotool key --clearmodifiers Super+j && xdotool key --clearmodifiers Super+Shift+j:<Super><Shift>j"
    ["swap-window-up"]="xdotool key --clearmodifiers Super+k && xdotool key --clearmodifiers Super+Shift+k:<Super><Shift>k"
    ["promote-to-master"]="xdotool key --clearmodifiers Super+BackSpace:<Super>BackSpace"
    ["toggle-layout"]="xdotool key --clearmodifiers Super+Shift+space:<Super><Shift>space"
    ["push-to-tile"]="wmctrl -r :ACTIVE: -b remove,maximized_vert,maximized_horz:<Super>Delete"
    ["toggle-float"]="xdotool key --clearmodifiers Super+t:<Super>t"
    ["inc-master"]="xdotool key --clearmodifiers Super+period:<Super>period"
    ["dec-master"]="xdotool key --clearmodifiers Super+comma:<Super>comma"
)

# Snap window keybindings
readonly -A SNAP_KEYS=(
    ["snap-left"]="${LOCAL_BIN}/snap-window left:<Super>h"
    ["snap-down"]="${LOCAL_BIN}/snap-window down:<Super>j"
    ["snap-up"]="${LOCAL_BIN}/snap-window up:<Super>k"
    ["snap-right"]="${LOCAL_BIN}/snap-window right:<Super>l"
    ["expand-left"]="${LOCAL_BIN}/snap-window expand-left:<Super><Shift>h"
    ["expand-down"]="${LOCAL_BIN}/snap-window expand-down:<Super><Shift>j"
    ["expand-up"]="${LOCAL_BIN}/snap-window expand-up:<Super><Shift>k"
    ["expand-right"]="${LOCAL_BIN}/snap-window expand-right:<Super><Shift>l"
)

# Layout resizing keybindings
readonly -A LAYOUT_KEYS=(
    ["layout-shrink-h"]="xdotool key --clearmodifiers Super+Shift+y:<Super><Shift>y"
    ["layout-expand-h"]="xdotool key --clearmodifiers Super+Shift+o:<Super><Shift>o"
    ["layout-shrink-v"]="xdotool key --clearmodifiers Super+Shift+u:<Super><Shift>u"
    ["layout-expand-v"]="xdotool key --clearmodifiers Super+Shift+i:<Super><Shift>i"
)

# Application shortcuts
readonly -A APP_KEYS=(
    ["terminal-toggle"]="${LOCAL_BIN}/terminal-toggle toggle:<Super>Return"
    ["terminal-new"]="${LOCAL_BIN}/terminal-toggle new:<Super><Shift>Return"
    ["app-launcher"]="rofi -show run:<Super>d"
    ["sudo-launcher"]="su_dmenu_run:<Super><Shift>d"
    ["system-actions"]="sysact:<Super>0"
    ["browser"]="brave-browser --no-default-browser-check:<Super>c"
    ["file-browser"]="thunar:<Super>x"
    ["file-search"]="pcmanfm --find-files:<Super><Shift>x"
    ["scratchpad-terminal"]="alacritty -t scratchpad:<Super><Shift>Return"
    ["music-player"]="audacious:<Super>m"
    ["firefox-scratchpad"]="firefox --class='FirefoxScratchpad' --enable-features=WebUIDarkMode --force-dark-mode:<Super>b"
    ["thunar-fzf"]="${LOCAL_BIN}/helpers/fzf-menu ${LOCAL_BIN}/helpers/fzf-thunar:<Super>p"
    ["code-fzf"]="${LOCAL_BIN}/helpers/fzf-menu ${LOCAL_BIN}/helpers/fzf-code:<Super>o"
    ["alacritty-fzf"]="${LOCAL_BIN}/helpers/fzf-menu ${LOCAL_BIN}/helpers/fzf-alacritty:<Super><Shift>p"
    ["thunderbird"]="thunderbird:F6"
    ["chat-app"]="chat-gpt:F7"
    ["system-monitor"]="sudo -A /usr/bin/stacer:F8"
    ["calculator"]="gnome-calculator:XF86Calculator"
    ["audio-control"]="pavucontrol:XF86Launch6"
    ["screenshot-gui"]="flameshot gui:Print"
    ["screenshot-menu"]="flameshot gui:XF86MenuPB"
)

# System control keybindings
readonly -A SYSTEM_KEYS=(
    ["restart-wm"]="cinnamon --replace:<Super>F6"
    ["logout-session"]="cinnamon-session-quit --logout:<Super><Shift>e"
)

# Media keys configuration
readonly -A MEDIA_KEYS=(
    ["volume-down"]="['XF86AudioLowerVolume']"
    ["volume-up"]="['XF86AudioRaiseVolume']"
    ["volume-mute"]="['XF86AudioMute']"
    ["play"]="['XF86AudioPlay']"
    ["stop"]="['XF86AudioStop']"
    ["previous"]="['XF86AudioPrev']"
    ["next"]="['XF86AudioNext']"
    ["screen-brightness-up"]="['XF86MonBrightnessUp']"
    ["screen-brightness-down"]="['XF86MonBrightnessDown']"
    ["screenshot"]="['Print']"
)

#============================================================================
# MAIN CONFIGURATION FUNCTIONS
#============================================================================

clear_default_shortcuts() {
    header "Clearing default shortcuts"

    # Clear workspace shortcuts (1-8)
    for i in {1..8}; do
        disable_key org.cinnamon.desktop.keybindings.wm switch-to-workspace-$i
        disable_key org.cinnamon.desktop.keybindings.wm move-to-workspace-$i
    done

    # Clear WM shortcuts
    for key in "${WM_KEYS_TO_DISABLE[@]}"; do
        disable_key org.cinnamon.desktop.keybindings.wm "$key"
    done

    # Clear conflicting media keys
    for key in "${MEDIA_KEYS_TO_DISABLE[@]}"; do
        disable_key org.cinnamon.desktop.keybindings.media-keys "$key"
    done

    # Clear other conflicting shortcuts
    disable_key org.gnome.settings-daemon.plugins.media-keys screensaver
    gsettings set org.cinnamon.desktop.keybindings looking-glass-keybinding "[]"

    # Preserve Alt+Tab
    gsettings set org.cinnamon.desktop.keybindings.wm switch-windows "['<Alt>Tab']" 2>/dev/null || true
    gsettings set org.cinnamon.desktop.keybindings.wm switch-windows-backward "['<Shift><Alt>Tab']" 2>/dev/null || true
}

configure_custom_keys() {
    local -A keys=("$@")
    for name in "${!keys[@]}"; do
        IFS=':' read -r cmd binding <<< "${keys[$name]}"
        set_custom_key "$name" "$cmd" "$binding"
    done
}

configure_window_management() {
    header "Configuring window management"
    configure_custom_keys "${WINDOW_MGMT_KEYS[@]}"
    configure_custom_keys "${SNAP_KEYS[@]}"
    configure_custom_keys "${LAYOUT_KEYS[@]}"
    gsettings set org.cinnamon.desktop.keybindings.wm toggle-fullscreen "['<Super>f']"
}

configure_applications() {
    header "Configuring applications"
    configure_custom_keys "${APP_KEYS[@]}"
}

configure_workspaces() {
    header "Configuring workspaces"

    # Workspace shortcuts (1-8)
    for i in {1..8}; do
        gsettings set org.cinnamon.desktop.keybindings.wm "switch-to-workspace-$i" "['<Super>$i']"
        gsettings set org.cinnamon.desktop.keybindings.wm "move-to-workspace-$i" "['<Super><Shift>$i']"
    done

    # Workspace navigation with arrows
    gsettings set org.cinnamon.desktop.keybindings.wm switch-to-workspace-left "['<Super>Left']"
    gsettings set org.cinnamon.desktop.keybindings.wm switch-to-workspace-right "['<Super>Right']"
    gsettings set org.cinnamon.desktop.keybindings.wm move-to-workspace-left "['<Super><Shift>Left']"
    gsettings set org.cinnamon.desktop.keybindings.wm move-to-workspace-right "['<Super><Shift>Right']"
}

install_dependencies() {
    header "Installing dependencies"
    log "Installing required packages..."
    sudo apt update && sudo apt install -y "${REQUIRED_PACKAGES[@]}"
}

install_scripts() {
    header "Installing scripts"
    mkdir -p "$LOCAL_BIN"

    for script_pair in "${SCRIPTS_TO_LINK[@]}"; do
        IFS=':' read -r source target <<< "$script_pair"
        local source_path="${SCRIPTS_DIR}/${source}"
        local target_path="${LOCAL_BIN}/${target}"

        if [[ -f "$source_path" ]]; then
            ln -sf "$source_path" "$target_path"
            log "Linked $target script"
        else
            warn "$source script not found in $SCRIPTS_DIR/"
        fi
    done
}

configure_system_control() {
    header "Configuring system control"
    configure_custom_keys "${SYSTEM_KEYS[@]}"
}

configure_wm_behavior() {
    header "Configuring WM behavior"
    gsettings set org.cinnamon.desktop.wm.preferences resize-with-right-button true
    gsettings set org.cinnamon.desktop.wm.preferences mouse-button-modifier '<Super>'
    gsettings set org.cinnamon.desktop.wm.preferences focus-mode 'click'
    gsettings set org.cinnamon.desktop.wm.preferences auto-raise false

    # Configure media keys
    for key in "${!MEDIA_KEYS[@]}"; do
        gsettings set org.cinnamon.desktop.keybindings.media-keys "$key" "${MEDIA_KEYS[$key]}"
    done
}

main() {
    check_desktop_environment
    header "Cinnamon XMonad-style Configuration"

    clear_default_shortcuts
    configure_window_management
    configure_applications
    configure_workspaces
    install_dependencies
    install_scripts
    configure_system_control
    configure_wm_behavior

    show_help
}

show_help() {
    header "Configuration complete!"
    cat << EOF
Key bindings configured (XMonad-compatible):

WINDOW MANAGEMENT:
• Super+{h,j,k,l} - snap windows in dynamic multi-monitor grid
• Super+Shift+{h,j,k,l} - expand/contract windows directionally
• Super+q - close window, Super+Shift+q - close all windows
• Super+s - focus master, Super+BackSpace - promote to master
• Super+Shift+{j,k} - swap windows up/down
• Super+f - fullscreen, Super+t - toggle float
• Super+Delete - push floating to tile
• Super+Shift+Space - toggle layout
• Super+Shift+{y,o,u,i} - resize layout (shrink/expand h/v)
• Super+{comma,period} - decrease/increase master pane count

APPLICATIONS:
• Super+Return - terminal toggle, Super+Shift+Return - new terminal
• Super+d - launcher, Super+Shift+d - sudo launcher
• Super+0 - system actions menu
• Super+c - browser, Super+b - firefox scratchpad
• Super+x - file browser, Super+Shift+x - file search
• Super+m - music player (audacious)
• Super+{p,o} - thunar/code fzf, Super+Shift+p - alacritty fzf
• F6 - thunderbird, F7 - chat, F8 - system monitor
• Print - screenshot

WORKSPACES:
• Super+{1-8} - switch to workspace
• Super+Shift+{1-8} - move window to workspace
• Super+{Left,Right} - navigate workspaces
• Super+Shift+{Left,Right} - move window to workspace

SYSTEM:
• Super+F6 - restart Cinnamon
• Super+Shift+e - logout
• Media keys preserved (volume, brightness, play/pause)

Log out/in for full effect. Customize via Cinnamon Settings > Keyboard > Shortcuts
EOF
}

main "$@"
