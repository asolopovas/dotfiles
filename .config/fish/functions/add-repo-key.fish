function add-repo-key
    if test (count $argv) -lt 2
        echo "Usage: add-repo-key <key> <repo_name> [--r | --rw]"
        echo "Example: add-repo-key \"ssh-rsa AAAA...\" asolopovas/lyntouch --rw"
        echo ""
        echo "Options:"
        echo "  --r   Read-only access (default)"
        echo "  --rw  Read-write access"
        return 1
    end

    set key_content $argv[1]
    set repo_name $argv[2]
    set read_only "true"

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

    if not gh auth status > /dev/null 2>&1
        echo "❌ GitHub CLI not authenticated. Run 'gh auth login'."
        return 1
    end

    set title (echo $key_content | awk '{print $NF}')
    set key_preview (echo $key_content | string sub -l 50)
    set permissions (test "$read_only" = "true"; and echo "📖 Read-Only"; or echo "✏️  Read-Write")

    echo "🔄 Adding deploy key to $repo_name..."
    echo ""

    set response (gh api -X POST /repos/$repo_name/keys \
        -f title="$title" \
        -f key="$key_content" \
        -f read_only="$read_only" 2>&1)
    
    # Clean up gh cli error output that comes after JSON
    set response (echo $response | string split "gh:" | head -1)
    
    set api_status $status

    if test $api_status -eq 0
        set id (echo $response | jq -r '.id')
        set key (echo $response | jq -r '.key' | string sub -l 50)
        set title (echo $response | jq -r '.title')
        set verified (echo $response | jq -r '.verified')
        set created_at (echo $response | jq -r '.created_at' | string replace 'T' ' ' | string replace 'Z' '')
        set verified_icon (test "$verified" = "true"; and echo "✅"; or echo "❌")

        echo "✅ Deploy key successfully added!"
        echo ""
        echo "═══════════════════════════════════════════════════════════════════"
        echo "  Repository:  $repo_name"
        echo "  Key ID:      $id"
        echo "  Title:       $title"
        echo "  Key:         $key..."
        echo "  Permissions: $permissions"
        echo "  Verified:    $verified_icon"
        echo "  Added:       $created_at"
        echo "═══════════════════════════════════════════════════════════════════"
        echo ""
        echo "💡 Commands:"
        echo "   • List all keys:  list-repo-keys $repo_name"
        echo "   • Remove key:     remove-repo-key $repo_name $id"
    else
        echo "❌ Failed to add deploy key"
        echo ""
        
        if echo $response | jq . >/dev/null 2>&1
            set error_msg (echo $response | jq -r '.message // "Unknown error"')
            set error_details (echo $response | jq -r '.errors[]?.message // empty' 2>/dev/null)
            
            if string match -q "*already in use*" "$error_details"
                echo "⚠️  Problem: This SSH key is already in use"
                echo ""
                echo "This key is already added to this repository or another one."
                echo "GitHub doesn't allow the same deploy key to be used multiple times."
                echo ""
                echo "💡 Solutions:"
                echo "   1. Check existing keys:  list-repo-keys $repo_name"
                echo "   2. Remove old key:       remove-repo-key $repo_name <key-id>"
                echo "   3. Generate a new key:   ssh-keygen -t rsa -b 4096 -C \"$repo_name\""
            else if string match -q "*Not Found*" "$error_msg"
                echo "⚠️  Problem: Repository not found"
                echo ""
                echo "The repository '$repo_name' was not found or you don't have access."
                echo ""
                echo "💡 Check:"
                echo "   • Repository name is correct (owner/repo format)"
                echo "   • You have admin access to the repository"
                echo "   • Repository exists: gh repo view $repo_name"
            else if string match -q "*Bad credentials*" "$error_msg"
                echo "⚠️  Problem: Authentication failed"
                echo ""
                echo "💡 Fix: Re-authenticate with GitHub"
                echo "   gh auth login"
            else
                echo "⚠️  Problem: $error_msg"
                if test -n "$error_details"
                    echo ""
                    echo "Details: $error_details"
                end
                echo ""
                echo "💡 Check the GitHub documentation for more info"
            end
        else
            echo "⚠️  Error: $response"
        end
        
        return 1
    end
end
