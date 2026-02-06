#!/bin/bash
cat <<'EOF'

  Tmux Cheatsheet

  DIRECT (no prefix needed)
  Ctrl+h                 Go to left pane
  Ctrl+j                 Go to pane below
  Ctrl+k                 Go to pane above
  Ctrl+l                 Go to right pane
  Alt+Left               Make pane wider (left)
  Alt+Right              Make pane wider (right)
  Alt+Up                 Make pane taller
  Alt+Down               Make pane shorter
  Alt+[                  Go to previous window
  Alt+]                  Go to next window
  Alt+{                  Move window to the left
  Alt+}                  Move window to the right
  Alt+1 to Alt+9         Go to window 1, 2, 3...

  Ctrl+Space  then...
  -                      Split pane top/bottom
  \                      Split pane left/right
  c                      Create new window
  ,                      Rename current window
  Tab                    Switch to last used window
  x                      Close current pane
  z                      Make pane fullscreen (toggle)
  !                      Turn pane into its own window
  @                      Pull a pane into this window
  o                      Swap pane position
  e                      Make all panes equal size

  Ctrl+Space  then...    SESSIONS
  w                      Browse all sessions and windows
  n                      Create a new session
  q                      Close current session
  d                      Disconnect from tmux
  ;                      Switch to last used session

  Ctrl+Space  then...    COPY & SEARCH
  /                      Search text in pane
  [                      Start selecting text
  v                      Begin highlight (in select mode)
  Ctrl+v                 Box highlight (in select mode)
  y                      Copy selected text

  Ctrl+Space  then...    POPUPS
  g                      Open lazygit
  G                      Open a floating terminal
  t                      Open htop

  Ctrl+Space  then...    OTHER
  r                      Reload tmux config
  Ctrl+l                 Clear the screen
  Ctrl+s                 Save all sessions to disk
  Ctrl+r                 Restore sessions from disk
  ?                      Show this cheatsheet

EOF
read -n 1 -s -r -p "  Press any key to close"
