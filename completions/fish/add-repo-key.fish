# Autocomplete for repository names under asolopovas
function __fish_add_repo_key_repos
    gh repo list asolopovas --json nameWithOwner --limit 100 | jq -r '.[].nameWithOwner'
end

# Complete second argument with repository names
complete -c add-repo-key -n "__fish_is_nth_token 2" -a "(__fish_add_repo_key_repos)" -d "Repository name"

# Complete third argument with permissions
complete -c add-repo-key -n "__fish_is_nth_token 3" -a "--r --rw" -d "Access level"
