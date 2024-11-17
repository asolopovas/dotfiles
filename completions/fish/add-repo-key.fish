# Autocomplete for repository names under asolopovas
function __fish_add_repo_key_repos
    gh repo list asolopovas --json nameWithOwner --limit 100 | jq -r '.[].nameWithOwner'
end

# Autocomplete for permissions (read-only or read-write)
function __fish_add_repo_key_permissions
    echo "--r --rw"
end

# Define completion for the `add-repo-key` command
# Second argument: repository names
complete -c add-repo-key \
    -n 'not __fish_seen_argument -i 2' \
    -a "(__fish_add_repo_key_repos)" \
    -d "Repositories under asolopovas"

# Third argument: permissions (--r or --rw)
complete -c add-repo-key \
    -n '__fish_seen_argument -i 2; and not __fish_seen_argument -i 3' \
    -a "(__fish_add_repo_key_permissions)" \
    -d "Access level: --r (read-only), --rw (read-write)"
