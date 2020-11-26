set -U fish_prompt_pwd_dir_length 0
set fish_color_search_match --background=blue


if test -n "$DESKTOP_SESSION"
    set -x (gnome-keyring-daemon --start --components=ssh | string split "=")
end


fish_vi_key_bindings

# Add user scripts
set -U fish_user_paths ~/.local/bin $fish_user_paths
set -U fish_user_paths ~/.local/bin $fish_user_paths
set -U fish_user_paths ~/.local/share/gem/bin $fish_user_paths
set -U fish_user_paths ~/.config/composer/vendor/bin $fish_user_paths
set -U fish_user_paths ~/.local/yarn/bin $fish_user_paths
set -U fish_user_paths ~/.yarn/bin $fish_user_paths
set -U fish_user_paths ~/.config/fzf/bin $fish_user_paths
