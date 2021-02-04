#!/bin/fish

if set -q DESKTOP_SESSION
    set -x (gnome-keyring-daemon --start --components=pkcs11,secrets,ssh,gpg | string split "=")
end

# ----------------------------------
# Fish
# ----------------------------------
fish_default_key_bindings
set fish_greeting
set fish_color_search_match --background=blue
set -U fish_prompt_pwd_dir_length 0

# ----------------------------------
# Add user scripts
# ----------------------------------
# set PATH $HOME/.local/bin                  $PATH
# set PATH $HOME/.local/share/gem/bin        $PATH
# set PATH $HOME/.config/composer/vendor/bin $PATH
# set PATH $HOME/.config/fzf/bin             $PATH
# set PATH (npm bin -g)                      $PATH

# ----------------------------------
# Env Variables
# ----------------------------------
set -x TERMINAL alacritty
set -x EDITOR nvim


# ----------------------------------
# Aliases
# ----------------------------------
alias pw='WP_TESTS_SKIP_INSTALL=1 phpunit-watcher watch'

# System
alias xclip='xclip -selection c'

# Cleanup
alias wget='wget --hsts-file="$XDG_CACHE_HOME/wget-hsts"'
alias tmux='tmux -f "$XDG_CONFIG_HOME"/tmux/tmux.conf'
alias gpg2='gpg2 --homedir "$XDG_DATA_HOME"/gnupg'

# ssh with google
alias sshg='ssh -i ~/.ssh/google_compute_engine'

# Docker-Sync
alias ds='docker-sync'
alias dss='docker-sync-stack'

# Docker
alias dc='docker-compose'
alias dcd='docker-compose -f docker-compose.dev.yml'
alias dk='docker'
alias dk-stop='docker stop (docker ps -a -q); docker rm (docker ps -a -q)'

# Github
alias gs='git status '
alias gw='git add -A && git commit -m "save"'
alias ga='git add '
alias gb='git branch '
alias gc='git add -A && git commit -m'
alias gd='git diff '
alias go='git checkout '
alias gk='gitk --all&'
alias gx='gitx --all'
alias nah='git reset --hard'
alias gp='git push'
alias gl='git pull'
alias gdrive-up='rclone copy .data/ gdrive:'
alias gdrive-down='rclone copy gdrive: .data/'

alias update-dev-conf='yarn remove dev-conf && yarn add https://github.com/asolopovas/dev-conf.git'

alias art='php artisan'
alias fd='fdfind'
alias rs='rsync -zrvhP '
alias l='ls -lah --group-directories-first'

alias sail='bash vendor/bin/sail'
