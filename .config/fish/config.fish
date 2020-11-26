if test -n "$DESKTOP_SESSION"
    set -x (gnome-keyring-daemon --start --components=ssh | string split "=")
end
