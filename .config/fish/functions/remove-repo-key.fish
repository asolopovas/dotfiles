function remove-repo-key
    if test (count $argv) -lt 2
        echo "Usage: remove-repo-key <repo_name> <key_id>"
        echo "Example: remove-repo-key asolopovas/lyntouch 12345678"
        echo ""
        echo "💡 To see key IDs, use: list-repo-keys <repo_name>"
        return 1
    end

    set repo_name $argv[1]
    set key_id $argv[2]

    if not gh auth status > /dev/null 2>&1
        echo "❌ GitHub CLI not authenticated. Run 'gh auth login'."
        return 1
    end

    echo "🔍 Fetching key details..."
    set key_info (gh api /repos/$repo_name/keys/$key_id 2>&1)
    set fetch_status $status

    if test $fetch_status -ne 0
        echo "❌ Failed to find key with ID: $key_id"
        if echo $key_info | jq . >/dev/null 2>&1
            set error_msg (echo $key_info | jq -r '.message // "Unknown error"')
            echo "   Error: $error_msg"
        end
        echo ""
        echo "💡 To list available keys, use: list-repo-keys $repo_name"
        return 1
    end

    set title (echo $key_info | jq -r '.title')
    set key_preview (echo $key_info | jq -r '.key' | string sub -l 50)
    set read_only (echo $key_info | jq -r '.read_only')
    set permissions (test "$read_only" = "true"; and echo "Read-Only"; or echo "Read-Write")

    echo ""
    echo "🗑️  About to remove this deploy key:"
    echo "═══════════════════════════════════════════════════════════════════"
    echo "  Repository:  $repo_name"
    echo "  Key ID:      $key_id"
    echo "  Title:       $title"
    echo "  Key:         $key_preview..."
    echo "  Permissions: $permissions"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    
    read -P "❓ Are you sure you want to remove this key? (y/N): " confirm
    
    if test "$confirm" != "y" -a "$confirm" != "Y"
        echo "❌ Removal cancelled."
        return 1
    end

    echo ""
    echo "🔄 Removing key..."
    set response (gh api -X DELETE /repos/$repo_name/keys/$key_id 2>&1)
    set delete_status $status

    if test $delete_status -eq 0
        echo "✅ Deploy key successfully removed!"
        echo ""
        echo "💡 Commands:"
        echo "   • List remaining keys: list-repo-keys $repo_name"
        echo "   • Add a new key:       add-repo-key \"<ssh-key>\" $repo_name [--rw]"
    else
        echo "❌ Failed to remove deploy key."
        if echo $response | jq . >/dev/null 2>&1
            set error_msg (echo $response | jq -r '.message // "Unknown error"')
            echo "   Error: $error_msg"
        else
            echo "   Error: $response"
        end
        return 1
    end
end