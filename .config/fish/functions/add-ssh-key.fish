function add-ssh-key
    # Ensure you're providing your public key as the argument
    if test (count $argv) -lt 1
        echo "Usage: add-ssh-key <public_key_file>"; return 1
    end

    set public_key_file $argv[1]

    # Check if the provided file exists
    if not test -f $public_key_file
        echo "❌ The file $public_key_file does not exist."; return 1
    end

    # Read the public key content
    set public_key (cat $public_key_file | string trim)

    echo "🔑 Connecting to root to append the key to valid user accounts..."

    ssh root "
        # List directories in /home, excluding system folders
        for user in (ls -1 /home | grep -Ev '^(.cpcpan|.cpan|nginx|.ssh|virtfs|cPanelInstall|.rapid-scan-db)$')
            if test -d /home/\$user  # Ensure it's a valid directory
                set user_home /home/\$user
                set ssh_dir \$user_home/.ssh
                set authorized_keys \$ssh_dir/authorized_keys

                # Create the .ssh directory if it doesn't exist
                if not test -d \$ssh_dir
                    echo \"ℹ️  Creating .ssh directory for user: \$user\"
                    mkdir -p \$ssh_dir
                    chmod 700 \$ssh_dir
                    chown \$user:\$user \$ssh_dir
                end

                # Append the public key to the authorized_keys file
                echo \"$public_key\" | tee -a \$authorized_keys > /dev/null
                chmod 600 \$authorized_keys
                chown \$user:\$user \$authorized_keys

                echo \"✅ Public key added for user: \$user\"
            else
                echo \"⚠️  Skipping invalid or non-user directory: \$user\"
            end
        end
    "

    echo "🎉 Successfully added the public key to valid user accounts!"
end
