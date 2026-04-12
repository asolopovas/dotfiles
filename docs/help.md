# Dotfiles Help                                    F1 toggle | q quit

## Focus & Move

```
 Key             │ Action                Key             │ Action             
 ────────────────┼────────────────────   ────────────────┼────────────────────
 M-j / M-k       │ Focus down / up       M-S-j / M-S-k   │ Swap down / up     
 M-s             │ Focus master          M-Backspace     │ Promote to master  
 M-h / M-l       │ Cycle screens         M-S-h / M-S-l   │ Move win to screen 
 M-1..9          │ Go to workspace       M-S-1..9        │ Move win to ws     
 M-q             │ Kill window           M-S-q           │ Kill all ws wins   
```

## Layout & Resize

```
 Key             │ Action                Key             │ Action             
 ────────────────┼────────────────────   ────────────────┼────────────────────
 M-S-Space       │ Next layout           M-f             │ Toggle fullscreen  
 M-S-y           │ Shrink horiz          M-S-o           │ Expand horiz       
 M-S-u           │ Shrink vert           M-S-i           │ Expand vert        
 M-. / M-,       │ +/- master count      M-t             │ Toggle float       
 M-Delete        │ Sink floating                         │                    
```

## Apps & Scratchpads

```
 Key             │ Action                Key             │ Action             
 ────────────────┼────────────────────   ────────────────┼────────────────────
 M-Return        │ Terminal              M-S-Return      │ Float terminal     
 M-d             │ Dmenu                 M-0             │ Sysact menu        
 M-b             │ Firefox               M-c             │ Brave              
 M-x             │ Thunar                M-S-x           │ Pcmanfm search     
 M-m             │ AIMP                  F7              │ AIMP delete track  
 F6              │ Thunderbird           F8              │ Stacer             
 Calculator      │ Calculator            Launch6         │ Pavucontrol        
 M-p             │ fzf Thunar            M-o             │ fzf Code           
 M-S-p           │ fzf Alacritty         Print           │ Flameshot          
 M-F6            │ Recompile xmonad      M-S-e           │ Quit xmonad        
```

## Tmux - Ctrl+Space

```
 Key             │ Action                Key             │ Action             
 ────────────────┼────────────────────   ────────────────┼────────────────────
 C-h/j/k/l       │ Move panes (nopfx)    Alt+Arrows      │ Resize pane        
 Alt+[ / ]       │ Prev / next win       Alt+1..9        │ Jump to window     
 - / \           │ Split h / v           c               │ New window         
 Tab             │ Last window           x               │ Kill pane          
 z               │ Zoom toggle           !               │ Break pane to win  
 w               │ Session tree          n               │ New session        
 g / G / t       │ Lazygit / sh / ht     ?               │ Cheatsheet popup   
```

## Neovim - Space

```
 Key             │ Action                Key             │ Action             
 ────────────────┼────────────────────   ────────────────┼────────────────────
 <C-p>           │ Smart file finder     <leader>ff      │ Find files         
 <leader>fg      │ Live grep             <leader>fb      │ File browser       
 <leader>h/l     │ Prev / next buf       <leader>bd      │ Close buffer       
 <leader>vv/vh   │ Split vert / hori     <M-h/j/k/l>     │ Move splits        
 <leader>f       │ Format                <leader><spc>   │ Clear search       
 <leader>pv      │ File explorer         <M-`>           │ Toggle NvimTree    
 <leader>ev/er   │ Edit init / remap     <leader>ef/ea   │ Edit fish / alias  
 J/K visual      │ Move selection        <F5>            │ Toggle hidden chr  
```

## Git

```
 Alias           │ Action                Alias           │ Action             
 ────────────────┼────────────────────   ────────────────┼────────────────────
 gs              │ status                gc              │ add + commit       
 gp              │ push                  gl              │ pull               
 gd              │ diff                  ga              │ amend              
 gk              │ checkout              gg              │ log                
 gundo           │ reset HEAD~1          nah             │ hard reset + clean 
```

## Shell

```
 Alias           │ Action                Alias           │ Action             
 ────────────────┼────────────────────   ────────────────┼────────────────────
 tm              │ tmux main             tx              │ attach session     
 ts              │ list sessions         dt              │ cd dotfiles        
 scr             │ cd scripts            l               │ ls -lha            
 dc              │ docker compose        dk              │ docker             
 rs              │ rsync                 m               │ mosh               
 upd             │ apt upgrade           pn              │ pnpm               
```

## Surround.vim

```
 Old Text        │ Cmd    │ Result       Old Text        │ Cmd    │ Result    
 ────────────────┼────────┼───────────   ────────────────┼────────┼───────────
 surr*ound       │ ysiw)  │ (surround)   [del*ete]       │ ds]    │ delete    
 'quot*es'       │ cs'"   │ "quotes"     <b>ta*g</b>     │ dst    │ tag       
```
