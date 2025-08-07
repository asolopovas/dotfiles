function __fish_list_repo_keys_repos
    gh repo list asolopovas --json nameWithOwner --limit 100 2>/dev/null | jq -r '.[].nameWithOwner' 2>/dev/null
end

complete -c list-repo-keys -n "__fish_is_nth_token 1" -a "(__fish_list_repo_keys_repos)" -d "Repository name"