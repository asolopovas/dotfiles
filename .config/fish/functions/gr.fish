function gr
    set repos (gh repo list asolopovas --json nameWithOwner --jq '.[].nameWithOwner' | string split "\n")
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
