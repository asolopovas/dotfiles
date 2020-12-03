[ ! -d $XMONAD_DATA_HOME ] && mkdir $XMONAD_DATA_HOME

export LC_ALL="en_GB.UTF-8"
export _JAVA_AWT_WM_NONREPARENTING=1
export SUDO_ASKPASS="$HOME/.local/bin/dmenupass"
export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"

# Applications
export BROWSER="google-chrome-stable"
export FILEMANAGER="thunar"
export TERMINAL="alacrity"
export FZF_DEFAULT_OPTS="--layout=reverse --height 30%"

# ~/ Clean-Up
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
export LESSHISTFILE="-"
export LESS=-R
export NPM_CONFIG_USERCONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/npm/npmrc"
export NVM_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvm"
export PASSWORD_STORE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/password-store"
export TMUX_TMPDIR="$XDG_RUNTIME_DIR"
export WEECHAT_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/weechat"
export WGETRC="${XDG_CONFIG_HOME:-$HOME/.config}/wget/wgetrc"
export WINEPREFIX="${XDG_DATA_HOME:-$HOME/.local/share}/wineprefixes/default"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XMONAD_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}/xmonad"
export XMONAD_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/xmonad"
export XMONAD_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/xmonad"

# sudo -n loadkeys ${XDG_DATA_HOME:-$HOME/.local/share}/ttymaps.kmap 2>/dev/null
# Program Settings
source ~/.env
