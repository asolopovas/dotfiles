OS=$(awk '/^ID=/' /etc/os-release | sed -e 's/ID=//' -e 's/"//g' | tr '[:upper:]' '[:lower:]')
export QT_QPA_PLATFORMTHEME="qt5ct"
export LESSHISTFILE="-"
export LESS=-R
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export GTK2_RC_FILES="$HOME/.config/gtk-2.0/.gtkrc-2.0"
export HOSTALIASES="$HOME/.hosts"
export PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig/xorg-server.pc:$PKG_CONFIG_PATH
export BROWSER="/usr/bin/brave-browser"

[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$PATH"

export NVM_DIR="$HOME/.config/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
