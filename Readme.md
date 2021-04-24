# Terminal
```
ctrl x e        'Edit command line
esc + b         'Word back
esc + f         'Word forward
```

# Command substitution
<!-- 'Value equals value of shell or /bin/sh if shell is not present -->
```
${SHELL:-"/bin/sh"}
```

# Tmux
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

# Vim
```
Ctrl + V        'Visual block mode
Shift + >       'Indent line'
Shift + n>      'Indent line n steps'
F7              'reindent file
```

# Install dotfile

```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/asolopovas/dotfiles/master/dotfiles-install.sh)"
```
