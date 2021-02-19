# sudo -n loadkeys ${XDG_DATA_HOME:-$HOME/.local/share}/ttymaps.kmap 2>/dev/null
[ ! -d $XMONAD_DATA_HOME ] && mkdir $XMONAD_DATA_HOME

export LC_ALL="en_GB.UTF-8"
export _JAVA_AWT_WM_NONREPARENTING=1
export SUDO_ASKPASS="$HOME/.local/bin/tools/dmenupass"
export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"

# Applications
export BROWSER="google-chrome-stable"
export FILEMANAGER="thunar"
export TERMINAL="alacrity"

# Clean-Up
export LESSHISTFILE="-"
export LESS=-R
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export ANDROID_SDK_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/android"
export DOCKER_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/docker"
export GEM_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/gem"
export GEM_SPEC_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/gem"
export GNUPGHOME="${XDG_CONFIG_HOME:-$HOME/.config}/gnupg"
export GNUPGHOME="${XDG_DATA_HOME:-$HOME/.local/share}/gnupg"
export GOPATH="${XDG_DATA_HOME:-$HOME/.local/share}/go"
export GTK2_RC_FILES="$HOME/.config/gtk-2.0/.gtkrc-2.0"
export INPUTRC="${XDG_CONFIG_HOME:-$HOME/.config}/inputrc"
export KDEHOME="${XDG_CONFIG_HOME:-$HOME/.config}/kde"
export NPM_CONFIG_USERCONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/npm/npmrc"
export NVM_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvm"
export PASSWORD_STORE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/password-store"
export TMUX_TMPDIR="$XDG_RUNTIME_DIR"
export WEECHAT_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/weechat"
export WGETRC="${XDG_CONFIG_HOME:-$HOME/.config}/wget/wgetrc"
export WINEPREFIX="${XDG_DATA_HOME:-$HOME/.local/share}/wineprefixes/default"
export XMONAD_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}/xmonad"
export XMONAD_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/xmonad"
export XMONAD_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/xmonad"
export HOSTALIASES=~/.hosts

# FZF Settings
export FZF_DEFAULT_OPTS="--layout=reverse --height 40%"
export FZF_DEFAULT_COMMAND='fd -E node_modules -E Steam -E npm -E skype -E vscode -E Code -E chrome -E Cache -E cache -E gem -E fish -E python -E .git -E mozilla -E cargo -E log . $HOME'
export FZF_CTRL_T_COMMAND=$FZF_DEFAULT_COMMAND
export FZF_ALT_C_COMMAND='fd -t d -E node_modules -E Steam -E npm -E skype -E vscode -E Code -E chrome -E Cache -E cache -E gem -E fish -E python -E .git -E mozilla -E cargo -E log . $HOME'

# Docker Settings
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

# Load script paths
load_scripts() {
  if [ -d "${HOME}${1}" ]; then
    scriptsPath="$scriptsPath:$(du "${HOME}${1}" | cut -f2 | tr '\n' ':' | sed 's/:*$//')"
  fi
}

load_scripts /.local/bin
load_scripts /.local/bin/helpers
load_scripts /.local/bin/apps
load_scripts /.local/bin/statusbar
load_scripts /.local/bin/system
load_scripts /.local/bin/tools
load_scripts /.local/bin/web
load_scripts /.local/share/gem/bin
load_scripts /.config/composer/vendor/bin
load_scripts /.config/fzf/bin

export PATH="$PATH:${scriptsPath:1}"

# Load NVM
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
