function __fish_remove_repo_key_repos
    gh repo list asolopovas --json nameWithOwner --limit 100 2>/dev/null | jq -r '.[].nameWithOwner' 2>/dev/null
end

function __fish_remove_repo_key_ids
    set repo (commandline -opc)[2]
    if test -n "$repo"
        gh api /repos/$repo/keys 2>/dev/null | jq -r '.[] | "\(.id)\t\(.title)"' 2>/dev/null
    end
end

complete -c remove-repo-key -n "__fish_is_nth_token 1" -a "(__fish_remove_repo_key_repos)" -d "Repository name"
complete -c remove-repo-key -n "__fish_is_nth_token 2" -a "(__fish_remove_repo_key_ids)" -d "Key ID"