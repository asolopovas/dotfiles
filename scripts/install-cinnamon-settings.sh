#!/bin/bash
# Cinnamon shortcuts configuration - XMonad-inspired window management
set -e

# Colors
G='\033[0;32m' Y='\033[1;33m' R='\033[0;31m' B='\033[0;34m' NC='\033[0m'
log() { echo -e "${G}[INFO]${NC} $1"; }
warn() { echo -e "${Y}[WARN]${NC} $1"; }
err() { echo -e "${R}[ERROR]${NC} $1"; }
header() { echo -e "${B}=== $1 ===${NC}"; }

# Environment check
[[ "$XDG_CURRENT_DESKTOP" != *"Cinnamon"* ]] && [[ "$DESKTOP_SESSION" != *"cinnamon"* ]] && {
    warn "Not running Cinnamon desktop"; read -p "Continue? (y/N): " -n1 -r; echo; [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
}

USER_HOME="$(eval echo ~$USER)"

# Utility functions
set_key() { 
    local name="$1" cmd="$2" key="$3"
    gsettings set org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/$name/ name "$name"
    gsettings set org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/$name/ command "$cmd"
    gsettings set org.cinnamon.desktop.keybindings.custom-keybinding:/org/cinnamon/desktop/keybindings/custom-keybindings/$name/ binding "['$key']"
    
    local list=$(gsettings get org.cinnamon.desktop.keybindings custom-list)
    [[ "$list" == "@as []" ]] && list="['$name']" || list=$(echo "$list" | sed "s/]$/, '$name']/")
    gsettings set org.cinnamon.desktop.keybindings custom-list "$list"
}

disable_key() { gsettings set "$1" "$2" "[]" 2>/dev/null || true; }

main() {
    header "Cinnamon XMonad-style Configuration"
    
    # Clear conflicting defaults
    header "Clearing default shortcuts"
    for i in {1..8}; do
        disable_key org.cinnamon.desktop.keybindings.wm switch-to-workspace-$i
        disable_key org.cinnamon.desktop.keybindings.wm move-to-workspace-$i
    done
    
    # Clear WM shortcuts
    for key in close toggle-fullscreen toggle-maximized minimize maximize unmaximize \
              switch-to-workspace-{left,right,up,down} move-to-workspace-{left,right,up,down} \
              panel-run-dialog show-desktop; do
        disable_key org.cinnamon.desktop.keybindings.wm $key
    done
    
    # Clear media keys that might conflict
    for key in terminal home search screensaver; do
        disable_key org.cinnamon.desktop.keybindings.media-keys $key
    done
    
    # Clear GNOME settings daemon keybindings that conflict
    disable_key org.gnome.settings-daemon.plugins.media-keys screensaver
    
    # Preserve Alt+Tab (skip if keys don't exist)
    gsettings set org.cinnamon.desktop.keybindings.wm switch-windows "['<Alt>Tab']" 2>/dev/null || true
    gsettings set org.cinnamon.desktop.keybindings.wm switch-windows-backward "['<Shift><Alt>Tab']" 2>/dev/null || true
    
    header "Configuring window management"
    
    # Core window management
    set_key "close-window" "wmctrl -c :ACTIVE:" "<Super>q"
    
    # Dynamic multi-monitor snap-window (mod+hjkl)
    set_key "snap-left" "${USER_HOME}/.local/bin/snap-window left" "<Super>h"
    set_key "snap-down" "${USER_HOME}/.local/bin/snap-window down" "<Super>j" 
    set_key "snap-up" "${USER_HOME}/.local/bin/snap-window up" "<Super>k"
    set_key "snap-right" "${USER_HOME}/.local/bin/snap-window right" "<Super>l"
    
    # Expand functionality (mod+shift+hjkl)
    set_key "expand-left" "${USER_HOME}/.local/bin/snap-window expand-left" "<Super><Shift>h"
    set_key "expand-down" "${USER_HOME}/.local/bin/snap-window expand-down" "<Super><Shift>j"
    set_key "expand-up" "${USER_HOME}/.local/bin/snap-window expand-up" "<Super><Shift>k" 
    set_key "expand-right" "${USER_HOME}/.local/bin/snap-window expand-right" "<Super><Shift>l"
    
    gsettings set org.cinnamon.desktop.keybindings.wm toggle-fullscreen "['<Super>f']"
    
    header "Configuring applications"
    
    # Application shortcuts
    declare -A apps=(
        ["terminal-toggle"]="${USER_HOME}/.local/bin/terminal-toggle toggle:<Super>Return"
        ["terminal-new"]="${USER_HOME}/.local/bin/terminal-toggle new:<Super><Shift>Return"
        ["app-launcher"]="cinnamon-launcher:<Super>d"
        ["browser"]="brave-browser --no-default-browser-check:<Super>c"
        ["file-browser"]="thunar:<Super>x"
        ["scratchpad-terminal"]="alacritty -t scratchpad:<Super><Ctrl>Return"
        ["music-player"]="flatpak run com.github.taiko2k.tauonmb:<Super>m"
        ["firefox-scratchpad"]="firefox --class='FirefoxScratchpad':<Super>b"
        ["system-monitor"]="gnome-system-monitor:F8"
        ["calculator"]="gnome-calculator:XF86Calculator"
        ["audio-control"]="pavucontrol:XF86Launch6"
        ["chat-app"]="telegram-desktop:F7"
        ["screenshot-gui"]="flameshot gui:Print"
    )
    
    for key in "${!apps[@]}"; do
        IFS=':' read -r cmd binding <<< "${apps[$key]}"
        set_key "$key" "$cmd" "$binding"
    done
    
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
    
    header "Installing dependencies"
    
    # Install required packages
    log "Installing xdotool and other dependencies..."
    sudo apt update && sudo apt install -y xdotool wmctrl x11-xserver-utils
    
    header "Installing scripts"
    
    # Create symbolic links for scripts
    if [[ -f "${HOME}/dotfiles/scripts/snap-window" ]]; then
        ln -sf "${HOME}/dotfiles/scripts/snap-window" ~/.local/bin/snap-window
        log "Linked snap-window script"
    else
        warn "snap-window script not found in dotfiles/scripts/"
    fi
    
    # Create symbolic link for terminal-toggle script
    if [[ -f "${HOME}/dotfiles/scripts/terminal-toggle" ]]; then
        ln -sf "${HOME}/dotfiles/scripts/terminal-toggle" ~/.local/bin/terminal-toggle
        log "Linked terminal-toggle script"
    else
        warn "terminal-toggle script not found in dotfiles/scripts/"
    fi
    
    header "Configuring WM behavior"
    
    # Window management behavior
    gsettings set org.cinnamon.desktop.wm.preferences resize-with-right-button true
    gsettings set org.cinnamon.desktop.wm.preferences mouse-button-modifier '<Super>'
    gsettings set org.cinnamon.desktop.wm.preferences focus-mode 'click'
    gsettings set org.cinnamon.desktop.wm.preferences auto-raise false
    
    # Media keys
    declare -A media=(
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
    
    for key in "${!media[@]}"; do
        gsettings set org.cinnamon.desktop.keybindings.media-keys "$key" "${media[$key]}"
    done
    
    header "Configuration complete!"
    
    # Compact help
    cat << EOF
Key bindings configured:
• Window Management: Super+{h,j,k,l} - snap windows in dynamic multi-monitor grid
• Expand Windows: Super+Shift+{h,j,k,l} - expand/contract windows directionally  
• Applications: Super+{Return,d,c,x,m,b} - terminal, launcher, browser, files, music, firefox
• Workspaces: Super+{1-8}, Super+Shift+{1-8} - switch/move to workspace
• System: Super+{q,f} - close/fullscreen, F8 - monitor, Print - screenshot

Log out/in for full effect. Customize via Cinnamon Settings > Keyboard > Shortcuts
EOF
}

main "$@"