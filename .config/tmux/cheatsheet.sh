#!/bin/bash
# sourced by: less -R ~/.config/tmux/cheatsheet.sh
# navigate: j/k scroll, / search, q quit
cat <<'EOF'
Tmux Cheatsheet                                              <leader> = Ctrl+a

 PANES                                    WINDOWS
 Ctrl+h/j/k/l   Move between panes        Alt+[ / ]       Prev / next window
 Alt+Arrows      Resize pane               Alt+{ / }       Move window left/right
 <leader> -      Split top/bottom          Alt+1..9        Jump to window
 <leader> \      Split left/right          <leader> c      New window
 <leader> x      Close pane                <leader> ,      Rename window
 <leader> z      Fullscreen (toggle)       <leader> Tab    Last window (toggle)
 <leader> o      Swap pane position
 <leader> e      Equal size all panes     SESSIONS
 <leader> !      Pane -> own window        <leader> w      Browse sessions/windows
 <leader> @      Pull pane from window     <leader> n      New session
                                           <leader> ;      Last session (toggle)
 COPY & SEARCH                             <leader> q      Kill session
 <leader> /      Search                    <leader> d      Detach
 <leader> [      Enter copy mode
 v               Select (copy mode)       POPUPS
 Ctrl+v          Rectangle select          <leader> g      Lazygit
 y               Yank (copy mode)          <leader> G      Floating terminal
                                           <leader> t      htop
 OTHER
 <leader> r      Reload config            SHELL COMMANDS (after detach)
 <leader> Ctrl+l Clear screen              tm              Create/attach "main"
 <leader> Ctrl+s Save sessions             tx <name>       Attach to session
 <leader> Ctrl+r Restore sessions          ts              List sessions
 <leader> ?      This cheatsheet           tmux attach     Attach to last session
EOF
