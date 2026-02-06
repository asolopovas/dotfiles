#!/bin/bash
cat <<'EOF'

  Tmux Cheatsheet                    <leader> = Ctrl+Space

  PANES
  Ctrl+h/j/k/l           Move between panes
  Alt+Arrow keys          Resize pane
  <leader> -              Split top/bottom
  <leader> \              Split left/right
  <leader> x              Close pane
  <leader> z              Fullscreen pane (toggle)
  <leader> o              Swap pane position
  <leader> e              Make all panes equal size
  <leader> !              Turn pane into its own window
  <leader> @              Pull a pane into this window

  WINDOWS
  Alt+[ / Alt+]           Previous / next window
  Alt+{ / Alt+}           Move window left / right
  Alt+1 to Alt+9          Jump to window by number
  <leader> c              New window
  <leader> ,              Rename window
  <leader> Tab            Last used window (toggle)

  SESSIONS
  <leader> w              Browse sessions and windows
  <leader> n              New session
  <leader> ;              Last used session (toggle)
  <leader> q              Kill session
  <leader> d              Detach from tmux

  COPY & SEARCH
  <leader> /              Search in pane
  <leader> [              Enter copy mode
  v                       Start selection (in copy mode)
  Ctrl+v                  Rectangle selection (in copy mode)
  y                       Copy selection (in copy mode)

  POPUPS
  <leader> g              Lazygit
  <leader> G              Floating terminal
  <leader> t              htop

  OTHER
  <leader> r              Reload config
  <leader> Ctrl+l         Clear screen
  <leader> Ctrl+s         Save sessions to disk
  <leader> Ctrl+r         Restore sessions from disk
  <leader> ?              This cheatsheet

EOF
read -n 1 -s -r -p "  Press any key to close"
