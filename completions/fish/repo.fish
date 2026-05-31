function __fish_repo_repos
    repo --complete 2>/dev/null
end

complete -c repo -f -n "__fish_is_nth_token 1" -a "(__fish_repo_repos)" -d Repository
complete -c repo -f -l https -d "Clone with HTTPS"
complete -c repo -f -l pick -d "Pick repository with fzf"
complete -c repo -f -l fzf -d "Pick repository with fzf"
complete -c repo -f -l list -d "List cached repositories"
complete -c repo -f -l refresh-cache -d "Refresh repository cache"
complete -c repo -f -s h -l help -d "Show help"
complete -c repo-clone -w repo
