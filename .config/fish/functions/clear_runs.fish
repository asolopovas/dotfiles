#!/usr/bin/env fish

function clear_runs
    if test (count $argv) -ne 2
        echo "Usage: clean_actions_runs <owner> <repository>"
        return 1
    end

    set REPO_OWNER $argv[1]
    set REPO_NAME $argv[2]

    set workflow_runs (gh api -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" /repos/$REPO_OWNER/$REPO_NAME/actions/runs --paginate -q '.workflow_runs[].id')

    if test (count $workflow_runs) -eq 0
        echo "No workflow runs found."
        return
    end

    for run_id in $workflow_runs
        echo "Deleting workflow run ID: $run_id"
        gh api --method DELETE -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" /repos/$REPO_OWNER/$REPO_NAME/actions/runs/$run_id
    end

    echo "All workflow runs have been deleted."
end
