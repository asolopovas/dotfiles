function add-repo-key
    if test (count $argv) -lt 2
        echo "Usage: add-repo-key <key> <repo_name> [--r | --rw]"; return 1
    end

    set key_content $argv[1]
    set repo_name $argv[2]
    set read_only "true"  # Default to read-only

    # Parse flags for permissions
    for arg in $argv
        switch $arg
            case --rw
                set read_only "false"
                break
            case --r
                set read_only "true"
                break
        end
    end

    if not gh auth status > /dev/null
        echo "GitHub CLI not authenticated. Run 'gh auth login'."; return 1
    end

     # Extract the title from the key
    set title (echo $key_content | awk '{print $NF}')

    # Send API request
    set response (gh api -X POST /repos/$repo_name/keys \
        -F title="$title" \
        -F key="$key_content" \
        -F read_only="$read_only")

    if test $status -eq 0
        set id (echo $response | jq -r '.id')
        set key (echo $response | jq -r '.key')
        set url (echo $response | jq -r '.url')
        set title (echo $response | jq -r '.title')
        set verified (echo $response | jq -r '.verified')dd
        set created_at (echo $response | jq -r '.created_at')

        echo "----------------------------------------"
        echo "🎉 Key added successfully!"
        echo "----------------------------------------"
        echo "📄 **Key Details:**"
        echo "  🔑 ID:        $id"
        echo "  🗝️ Key:        $key"
        echo "  🔗 URL:       $url"
        echo "  📛 Title:     $title"
        echo "  ✅ Verified:  $verified"
        echo "  🔒 Permission: "(test $read_only = "true"; and echo 'Read-Only'; or echo 'Read-Write')
        echo "  🕒 Created:   $created_at"
        echo "----------------------------------------"
    else
        echo "❌ Failed to add key."; return 1
    end
end
