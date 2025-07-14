#!/usr/bin/env fish

function add-git-ssh
    set -l key_file $argv[1]

    if test -z "$key_file"
        echo "Error: Please provide an SSH key file"
        echo "Usage: add-git-ssh ./path/to/key.pub"
        return 1
    end

    if not test -f "$key_file"
        echo "Error: File '$key_file' not found"
        return 1
    end

    if not string match -q "*.pub" "$key_file"
        echo "Error: Please provide a public key file (*.pub)"
        return 1
    end

    set -l key_title (basename "$key_file" .pub)

    set -l key_content (cat "$key_file")

    gh ssh-key add "$key_content" --title "$key_title"

    if test $status -eq 0
        echo "Successfully added SSH key from $key_file to GitHub"
    else
        echo "Failed to add SSH key"
        return 1
    end
end

# Add completion for the command
complete -c add-git-ssh -f -a "(__fish_complete_path)" -d "Add SSH key to GitHub"
