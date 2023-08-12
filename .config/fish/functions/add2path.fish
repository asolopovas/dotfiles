function add2path
    set -l full_path
    if string match -qr '^/' -- $argv
        set full_path "$argv"
    else
        set full_path "$HOME/$argv"
    end

    if test -d $full_path; and not contains $full_path $PATH
        set -U fish_user_paths $full_path $fish_user_paths
    end
end
