#!/bin/bash
# tmux cheatsheet displayed in a popup (prefix + ?)
cat <<'EOF'
 ┌─────────────────────────────────────────────────────┐
 │              Tmux Cheatsheet (C-a = prefix)         │
 ├──────────────┬──────────────────────────────────────┤
 │  WINDOWS     │                                      │
 │  n           │  New window                          │
 │  A           │  Rename window                       │
 │  Alt-1..9    │  Jump to window (no prefix)          │
 │  Alt-h / l   │  Prev / next window (no prefix)     │
 │  Alt-H / L   │  Move window left / right            │
 ├──────────────┼──────────────────────────────────────┤
 │  SPLITS      │                                      │
 │  c           │  Split horizontal                    │
 │  v           │  Split vertical                      │
 │  C-h/j/k/l   │  Move between panes (vim-aware)     │
 │  H/J/K/L     │  Resize pane                        │
 │  z           │  Toggle zoom                         │
 │  Enter       │  Break pane to window                │
 │  Space       │  Join pane from window               │
 │  x / X       │  Kill pane / Kill window             │
 ├──────────────┼──────────────────────────────────────┤
 │  LAYOUTS     │                                      │
 │  Tab         │  Cycle layouts                       │
 │  M-1..5      │  Even-h, Even-v, Main-h, Main-v,    │
 │              │  Tiled                               │
 ├──────────────┼──────────────────────────────────────┤
 │  SESSIONS    │                                      │
 │  s           │  Session tree picker                 │
 │  S           │  New named session                   │
 │  K           │  Kill session                        │
 │  f           │  Find window                         │
 ├──────────────┼──────────────────────────────────────┤
 │  COPY MODE   │                                      │
 │  /           │  Search                              │
 │  v / C-v     │  Selection / rectangle               │
 │  y           │  Yank                                │
 ├──────────────┼──────────────────────────────────────┤
 │  POPUPS      │                                      │
 │  g           │  Lazygit                             │
 │  G           │  Floating shell                      │
 │  t           │  htop                                │
 ├──────────────┼──────────────────────────────────────┤
 │  OTHER       │                                      │
 │  r           │  Reload config                       │
 │  C-l         │  Clear screen                        │
 │  d           │  Detach                              │
 │  C-s / C-r   │  Save / restore session              │
 │  ?           │  This cheatsheet                     │
 └──────────────┴──────────────────────────────────────┘
EOF
read -n 1 -s -r -p " Press any key to close"
