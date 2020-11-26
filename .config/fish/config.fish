if test -z "$DESKTOP_SESSION"
    eval (gnome-keyring-daemon --start --components=ssh)
    set -Ux SSH_AUTH_SOCK
end

