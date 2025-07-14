function grp
    set repos (curl -s "https://api.github.com/users/asolopovas/repos" | jq -r '.[].full_name' | string split "\n")
    if not count $repos > 0
        echo "No repositories found for user asolopovas."
        return
    end

    for repo in $repos
        echo $repo
    end | fzf | read -l selected_repo

    if not test -n "$selected_repo"
        echo "Repository selection cancelled."
        return
    end

    git clone "https://github.com/$selected_repo.git"
end
