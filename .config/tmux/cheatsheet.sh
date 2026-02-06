#!/bin/bash
# sourced by: less -R ~/.config/tmux/cheatsheet.sh
# navigate: j/k scroll, / search, q quit
cat <<'EOF'
Tmux Cheatsheet            <leader> = Ctrl+Space

SHELL COMMANDS (after detach)
  tm              Attach or create "main" session
  tx <name>       Attach to session by name
  ts              List all sessions
  tl              List windows
  tk <name>       Kill session by name
  tmux attach     Attach to last session

PANES
  Ctrl+h/j/k/l   Move between panes
  Alt+Arrows      Resize pane
  <leader> -      Split top/bottom
  <leader> \      Split left/right
  <leader> x      Close pane
  <leader> z      Fullscreen (toggle)
  <leader> o      Swap pane position
  <leader> e      Equal size all panes
  <leader> !      Pane -> own window
  <leader> @      Pull pane from window

WINDOWS
  Alt+[ / ]       Prev / next window
  Alt+{ / }       Move window left / right
  Alt+1..9        Jump to window
  <leader> c      New window
  <leader> ,      Rename window
  <leader> Tab    Last window (toggle)

SESSIONS
  <leader> w      Browse sessions/windows
  <leader> n      New session
  <leader> ;      Last session (toggle)
  <leader> q      Kill session
  <leader> d      Detach

COPY & SEARCH
  <leader> /      Search
  <leader> [      Enter copy mode
  v               Select (copy mode)
  Ctrl+v          Rectangle select (copy mode)
  y               Yank (copy mode)

POPUPS
  <leader> g      Lazygit
  <leader> G      Floating terminal
  <leader> t      htop

OTHER
  <leader> r      Reload config
  <leader> Ctrl+l Clear screen
  <leader> Ctrl+s Save sessions
  <leader> Ctrl+r Restore sessions
  <leader> ?      This cheatsheet
EOF
