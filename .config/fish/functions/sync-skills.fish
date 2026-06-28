function sync-skills --description 'Pull latest shared agent skills and re-link across all AI CLIs'
    set -l repo "$HOME/dotfiles"
    set -l sub "$repo/agents"

    if not test -d "$sub"
        echo "sync-skills: missing submodule $sub (run: git -C $repo submodule update --init)" >&2
        return 1
    end

    echo "sync-skills: fetching latest agents from remote..."
    git -C "$repo" submodule sync --quiet agents
    git -C "$sub" fetch --quiet origin
    or begin
        echo "sync-skills: fetch failed" >&2
        return 1
    end
    git -C "$sub" checkout --quiet main 2>/dev/null
    if not git -C "$sub" pull --quiet --ff-only
        echo "sync-skills: could not fast-forward agents (local edits or diverged); resolve in $sub" >&2
        return 1
    end

    echo "sync-skills: re-linking skills into claude, codex, opencode, pi..."
    "$repo/scripts/sync-ai.sh" agents
end
