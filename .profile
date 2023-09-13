OS=$(awk '/^ID=/' /etc/os-release | sed -e 's/ID=//' -e 's/"//g' | tr '[:upper:]' '[:lower:]')
export QT_QPA_PLATFORMTHEME="qt5ct"
export LESSHISTFILE="-"
export LESS=-R
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export GTK2_RC_FILES="$HOME/.config/gtk-2.0/.gtkrc-2.0"
export HOSTALIASES="$HOME/.hosts"
DOTFILES="$HOME/dotfiles"

env_vars=(
    env-vars
    include-paths
    xmonad-vars
)

source_script() {
    local script_name=$1
    local script_path="$DOTFILES/env/$script_name.sh"
    [[ -f $script_path ]] && source $script_path || echo "Failed to source $script_path"
}

for env_var in "${env_vars[@]}"; do
    source_script $env_var
done
. "$HOME/.cargo/env"
