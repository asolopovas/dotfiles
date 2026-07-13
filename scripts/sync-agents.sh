#!/usr/bin/env bash
# Two-way sync of the agents submodule: commit + push local skill edits,
# rebase on the latest remote, then bump the parent pointer so nothing is left dirty.
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
AGENTS_DIR="${AGENTS_DIR:-$DOTFILES_DIR/agents}"
BRANCH="${AGENTS_BRANCH:-main}"
PUSH=1

while [ $# -gt 0 ]; do
    case "$1" in
        --no-push) PUSH=0 ;;
        --branch)
            BRANCH="$2"
            shift
            ;;
        *)
            echo "unknown arg: $1" >&2
            exit 2
            ;;
    esac
    shift
done

# 1. Ensure the submodule is initialized and on a real branch (not detached HEAD).
git -C "$DOTFILES_DIR" submodule update --init agents
if [ "$(git -C "$AGENTS_DIR" rev-parse --abbrev-ref HEAD)" != "$BRANCH" ]; then
    git -C "$AGENTS_DIR" checkout "$BRANCH"
fi

# 2. Commit any local edits made in the canonical skills tree.
if [ -n "$(git -C "$AGENTS_DIR" status --porcelain)" ]; then
    files=$(git -C "$AGENTS_DIR" status --porcelain | sed "s/^...//" | paste -sd ", " -)
    git -C "$AGENTS_DIR" add -A
    git -C "$AGENTS_DIR" commit -m "sync: update $files"
    echo "Committed local agents changes: $files"
fi

# 3. Pull the latest remote, replaying local commits on top.
git -C "$AGENTS_DIR" fetch origin "$BRANCH"
git -C "$AGENTS_DIR" pull --rebase origin "$BRANCH"

# 4. Push local commits upstream.
if [ "$PUSH" -eq 1 ]; then
    git -C "$AGENTS_DIR" push origin "$BRANCH"
    echo "Pushed agents to origin/$BRANCH"
fi

# 5. Record the (possibly new) submodule commit in the parent repo.
git -C "$DOTFILES_DIR" add agents
if ! git -C "$DOTFILES_DIR" diff --cached --quiet -- agents; then
    sha=$(git -C "$AGENTS_DIR" rev-parse --short HEAD)
    git -C "$DOTFILES_DIR" commit -m "agents: bump to $sha" -- agents
    echo "Bumped agents pointer to $sha"
fi
