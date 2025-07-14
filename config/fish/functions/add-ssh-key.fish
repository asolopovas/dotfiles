function add-ssh-key
    # Check arguments
    if test (count $argv) -lt 1
        echo "Usage: add-ssh-key [-f] <public_key_file>"
        return 1
    end

    # Default: append
    set force 0

    # Figure out if "-f" is provided
    if test $argv[1] = "-f"
        # Force overwrite
        set force 1

        # Make sure we got a key file after "-f"
        if test (count $argv) -lt 2
            echo "Usage: add-ssh-key -f <public_key_file>"
            return 1
        end
        set public_key_file $argv[2]
    else
        set public_key_file $argv[1]
    end

    # Ensure the key file exists
    if not test -f $public_key_file
        echo "❌ No valid public key file found: $public_key_file"
        return 1
    end

    # Read and trim the key
    set public_key (string trim (cat $public_key_file))

    echo "🔑 Connecting to root to update authorized_keys for real cPanel users..."

    # Send commands to the remote (root) to update keys
    ssh root "
        # 1) Get the list of cPanel accounts from /var/cpanel/users
        set cpanel_users (ls -1 /var/cpanel/users)

        # 2) For each user in that list, make sure it's a valid user, then update authorized_keys
        for user in \$cpanel_users
            # Check if /etc/passwd has an entry for \$user
            if id \$user > /dev/null 2>&1
                set user_home /home/\$user

                # Must have a valid home directory
                if test -d \$user_home
                    set ssh_dir \$user_home/.ssh
                    set authorized_keys \$ssh_dir/authorized_keys

                    # Create ~/.ssh if needed
                    if not test -d \$ssh_dir
                        echo \"ℹ️  Creating .ssh directory for user: \$user\"
                        mkdir -p \$ssh_dir
                        chmod 700 \$ssh_dir
                        chown \$user:\$user \$ssh_dir
                    end

                    # Overwrite (-f) or append
                    if test $force -eq 1
                        echo \"$public_key\" > \$authorized_keys
                        echo \"✅ Overwritten authorized_keys for user: \$user\"
                    else
                        echo \"$public_key\" >> \$authorized_keys
                        echo \"✅ Appended public key for user: \$user\"
                    end

                    chmod 600 \$authorized_keys
                    chown \$user:\$user \$authorized_keys
                else
                    echo \"⚠️  Skipping \$user: /home/\$user does not exist.\"
                end
            else
                echo \"⚠️  Skipping \$user: not a valid user in /etc/passwd.\"
            end
        end
    "

    echo "🎉 Finished updating authorized_keys for cPanel users!"
end
