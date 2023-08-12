## Terminal Shortcuts
```
ctrl x e        'Edit command line
esc + b         'Word back
esc + f         'Word forward
```

## Tmux Shortcuts
```
Ctrl+a c        'Create new window
Ctrl+a ,        'Rename window
Ctrl+a p        'Previous window
Ctrl+a n        'Next window
Ctrl+a w        'Select windows
Ctrl+a %        'Split vertically
Ctrl+a :        'Named commands
Ctrl+a d        'Detach from the session
Ctrl+a Alt + -  'Horizontal Layout
Ctrl+a Alt + |  'Vertical Layout
```

## Vim Shortcuts
```
Ctrl + V        'Visual block mode
Shift + >       'Indent line'
Shift + n>      'Indent line n steps'
F7              'reindent file
```

## Dotfiles (Menu Version)
```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/asolopovas/dotfiles/master/init.sh)"
```

## Dotfiles (Menu Version) No Cache Flag
```
bash -c "$(curl -fsSLH 'Cache-Control: no-cache'  https://raw.githubusercontent.com/asolopovas/dotfiles/master/init.sh)"
```

## Full Stack No Cache Versions No Cache Flag
```
FISH=true FZF=true FDFIND=true NVIM=true NVM=true OHMYFISH=true UNATTENDED=true bash -c "$(curl -fsSLH 'Cache-Control: no-cache' https://raw.githubusercontent.com/asolopovas/dotfiles/master/init.sh)"
```

## Dotfiles for WordPress Environment (Gutenberg Block Editings) ([wp-env](https://www.npmjs.com/package/@wordpress/env?activeTab=readme))
```
NODEVER=16.20.0 FZF=true FDFIND=true NVM=true OHMYBASH=true UNATTENDED=true bash -c "$(curl -fsSLH 'Cache-Control: no-cache' https://raw.githubusercontent.com/asolopovas/dotfiles/master/init.sh)"
```
