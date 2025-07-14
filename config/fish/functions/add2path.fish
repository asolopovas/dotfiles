function add2path
    for arg in $argv
        set -l fullPath
        if string match -qr '^/' -- $arg
            set fullPath "$arg"
        else
            set fullPath "$HOME/$arg"
        end

        if test -d "$fullPath"; and not contains "$fullPath" $fish_user_paths
            if type -q fish_add_path
                fish_add_path "$fullPath"
            else
                set -U fish_user_paths $fullPath $fish_user_paths
            end
        end
    end
end
