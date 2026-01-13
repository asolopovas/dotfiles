function list-repo-keys
    if test (count $argv) -lt 1
        echo "Usage: list-repo-keys <repo_name>"
        echo "Example: list-repo-keys asolopovas/lyntouch"
        return 1
    end

    set repo_name $argv[1]

    if not gh auth status > /dev/null 2>&1
        echo "❌ GitHub CLI not authenticated. Run 'gh auth login'."
        return 1
    end

    set response (gh api /repos/$repo_name/keys 2>&1)
    set api_status $status

    if test $api_status -ne 0
        echo "❌ Failed to fetch deploy keys for $repo_name"
        if echo $response | jq . >/dev/null 2>&1
            set error_msg (echo $response | jq -r '.message // "Unknown error"')
            echo "   Error: $error_msg"
        else
            echo "   Error: $response"
        end
        return 1
    end

    set key_count (echo $response | jq 'length')
    
    if test $key_count -eq 0
        echo "📭 No deploy keys found for $repo_name"
        echo ""
        echo "💡 To add a new key, use:"
        echo "   add-repo-key \"<ssh-key>\" $repo_name [--rw]"
        return 0
    end

    echo "🔑 Deploy Keys for $repo_name"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""

    for i in (seq 0 (math $key_count - 1))
        set key_data (echo $response | jq ".[$i]")
        set id (echo $key_data | jq -r '.id')
        set title (echo $key_data | jq -r '.title')
        set key_preview (echo $key_data | jq -r '.key' | string sub -l 50)
        set read_only (echo $key_data | jq -r '.read_only')
        set created_at (echo $key_data | jq -r '.created_at' | string replace 'T' ' ' | string replace 'Z' '')
        set verified (echo $key_data | jq -r '.verified')

        set permissions (test "$read_only" = "true"; and echo "📖 Read-Only"; or echo "✏️  Read-Write")
        set verified_icon (test "$verified" = "true"; and echo "✅"; or echo "❌")

        echo "  📌 Key #"(math $i + 1)
        echo "  ├─ ID:         $id"
        echo "  ├─ Title:      $title"
        echo "  ├─ Key:        $key_preview..."
        echo "  ├─ Permission: $permissions"
        echo "  ├─ Verified:   $verified_icon"
        echo "  └─ Added:      $created_at"
        echo ""
    end

    echo "═══════════════════════════════════════════════════════════════════"
    echo "Total: $key_count key(s)"
    echo ""
    echo "💡 Commands:"
    echo "   • Add new key:    add-repo-key \"<ssh-key>\" $repo_name [--rw]"
    echo "   • Remove key:     remove-repo-key $repo_name <key-id>"
end