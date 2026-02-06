#!/bin/bash
cat <<'EOF'

  Tmux Cheatsheet               Prefix = Ctrl+Space

  NO PREFIX (instant)
  Ctrl+h/j/k/l          Move between panes (vim-aware)
  Alt+Arrows             Resize pane
  Alt+[ / Alt+]          Prev / next window
  Alt+{ / Alt+}          Move window left / right
  Alt+1 .. Alt+9         Jump to window

  PREFIX + KEY
  -                      Split horizontal  ──
  \                      Split vertical    │
  c                      New window
  ,                      Rename window
  Tab                    Last window (toggle)
  x                      Kill pane
  z                      Zoom pane (toggle)
  !                      Break pane to window
  @                      Join pane from window
  o                      Swap pane down
  e                      Spread panes evenly

  SESSIONS
  w                      Session/window tree
  n                      New named session
  q                      Kill session
  d                      Detach
  ;                      Last session (toggle)

  COPY MODE
  /                      Search
  [                      Enter copy mode
  v / Ctrl+v             Select / rectangle
  y                      Yank

  POPUPS
  g                      Lazygit
  G                      Floating shell
  t                      htop

  OTHER
  r                      Reload config
  Ctrl+l                 Clear screen
  Ctrl+s                 Save session
  Ctrl+r                 Restore session
  ?                      This cheatsheet

EOF
read -n 1 -s -r -p "  Press any key to close"
