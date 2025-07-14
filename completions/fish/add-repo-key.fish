function __fish_add_repo_key_repos
    gh repo list asolopovas --json nameWithOwner --limit 100 | jq -r '.[].nameWithOwner'
end

complete -c add-repo-key -n "__fish_is_nth_token 2" -a "(__fish_add_repo_key_repos)" -d "Repository name"
complete -c add-repo-key -n "__fish_is_nth_token 3" -a "--r" -d "Read-Only"
complete -c add-repo-key -n "__fish_is_nth_token 3" -a "--rw" -d "Read-Write"
