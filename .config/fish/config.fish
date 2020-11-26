set -U fish_prompt_pwd_dir_length 0

if test -n "$DESKTOP_SESSION"
    set -x (gnome-keyring-daemon --start --components=ssh | string split "=")
end
