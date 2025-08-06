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
    
    # Clear Cinnamon Looking Glass (Melange) keybinding
    gsettings set org.cinnamon.desktop.keybindings looking-glass-keybinding "[]"
    
    # Preserve Alt+Tab (skip if keys don't exist)
    gsettings set org.cinnamon.desktop.keybindings.wm switch-windows "['<Alt>Tab']" 2>/dev/null || true
    gsettings set org.cinnamon.desktop.keybindings.wm switch-windows-backward "['<Shift><Alt>Tab']" 2>/dev/null || true
    
    header "Configuring window management"
    
    # Core window management
    set_key "close-window" "wmctrl -c :ACTIVE:" "<Super>q"
    set_key "close-all-windows" "wmctrl -c :ALL:" "<Super><Shift>q"
    set_key "focus-master" "wmctrl -a :SELECT:" "<Super>s"
    set_key "swap-window-down" "xdotool key --clearmodifiers Super+j && xdotool key --clearmodifiers Super+Shift+j" "<Super><Shift>j"
    set_key "swap-window-up" "xdotool key --clearmodifiers Super+k && xdotool key --clearmodifiers Super+Shift+k" "<Super><Shift>k"
    set_key "promote-to-master" "xdotool key --clearmodifiers Super+BackSpace" "<Super>BackSpace"
    set_key "toggle-layout" "xdotool key --clearmodifiers Super+Shift+space" "<Super><Shift>space"
    set_key "push-to-tile" "wmctrl -r :ACTIVE: -b remove,maximized_vert,maximized_horz" "<Super>Delete"
    set_key "toggle-float" "xdotool key --clearmodifiers Super+t" "<Super>t"
    
    # Dynamic multi-monitor snap-window (mod+hjkl)
    set_key "snap-left" "${USER_HOME}/.local/bin/snap-window left" "<Super>h"
    set_key "snap-down" "${USER_HOME}/.local/bin/snap-window down" "<Super>j" 
    set_key "snap-up" "${USER_HOME}/.local/bin/snap-window up" "<Super>k"
    set_key "snap-right" "${USER_HOME}/.local/bin/snap-window right" "<Super>l"
    
    # Expand functionality (mod+shift+hjkl) - now handled by snap-window expand
    set_key "expand-left" "${USER_HOME}/.local/bin/snap-window expand-left" "<Super><Shift>h"
    set_key "expand-down" "${USER_HOME}/.local/bin/snap-window expand-down" "<Super><Shift>j"
    set_key "expand-up" "${USER_HOME}/.local/bin/snap-window expand-up" "<Super><Shift>k" 
    set_key "expand-right" "${USER_HOME}/.local/bin/snap-window expand-right" "<Super><Shift>l"
    
    # Layout resizing (XMonad M-S-y/o/u/i)
    set_key "layout-shrink-h" "xdotool key --clearmodifiers Super+Shift+y" "<Super><Shift>y"
    set_key "layout-expand-h" "xdotool key --clearmodifiers Super+Shift+o" "<Super><Shift>o"
    set_key "layout-shrink-v" "xdotool key --clearmodifiers Super+Shift+u" "<Super><Shift>u"
    set_key "layout-expand-v" "xdotool key --clearmodifiers Super+Shift+i" "<Super><Shift>i"
    
    # Master pane controls
    set_key "inc-master" "xdotool key --clearmodifiers Super+period" "<Super>period"
    set_key "dec-master" "xdotool key --clearmodifiers Super+comma" "<Super>comma"
    
    gsettings set org.cinnamon.desktop.keybindings.wm toggle-fullscreen "['<Super>f']"
    
    header "Configuring applications"
    
    # Application shortcuts
    declare -A apps=(
        ["terminal-toggle"]="${USER_HOME}/.local/bin/terminal-toggle toggle:<Super>Return"
        ["terminal-new"]="${USER_HOME}/.local/bin/terminal-toggle new:<Super><Shift>Return"
        ["app-launcher"]="rofi -show run:<Super>d"
        ["sudo-launcher"]="su_dmenu_run:<Super><Shift>d"
        ["system-actions"]="sysact:<Super>0"
        ["browser"]="brave-browser --no-default-browser-check:<Super>c"
        ["file-browser"]="thunar:<Super>x"
        ["file-search"]="pcmanfm --find-files:<Super><Shift>x"
        ["scratchpad-terminal"]="alacritty -t scratchpad:<Super><Shift>Return"
        ["music-player"]="audacious:<Super>m"
        ["firefox-scratchpad"]="firefox --class='FirefoxScratchpad' --enable-features=WebUIDarkMode --force-dark-mode:<Super>b"
        ["thunar-fzf"]="${USER_HOME}/.local/bin/helpers/fzf-menu ${USER_HOME}/.local/bin/helpers/fzf-thunar:<Super>p"
        ["code-fzf"]="${USER_HOME}/.local/bin/helpers/fzf-menu ${USER_HOME}/.local/bin/helpers/fzf-code:<Super>o"
        ["alacritty-fzf"]="${USER_HOME}/.local/bin/helpers/fzf-menu ${USER_HOME}/.local/bin/helpers/fzf-alacritty:<Super><Shift>p"
        ["thunderbird"]="thunderbird:F6"
        ["chat-app"]="chat-gpt:F7"
        ["system-monitor"]="sudo -A /usr/bin/stacer:F8"
        ["calculator"]="gnome-calculator:XF86Calculator"
        ["audio-control"]="pavucontrol:XF86Launch6"
        ["screenshot-gui"]="flameshot gui:Print"
        ["screenshot-menu"]="flameshot gui:XF86MenuPB"
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
    
    header "Configuring XMonad control"
    
    # XMonad control keybindings
    set_key "restart-wm" "cinnamon --replace" "<Super>F6"
    set_key "logout-session" "cinnamon-session-quit --logout" "<Super><Shift>e"
    
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