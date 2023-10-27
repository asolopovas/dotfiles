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

. "$HOME/.cargo/env"
