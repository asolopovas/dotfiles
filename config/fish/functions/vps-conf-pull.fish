function vps-conf-pull
    echo "🔄 Connecting to root to run 'conf pull' for all cPanel users..."

    ssh root "
        # 1) Get the list of cPanel accounts from /var/cpanel/users
        set cpanel_users (ls -1 /var/cpanel/users)

        # 2) Iterate through each cPanel user
        for user in \$cpanel_users
            # Check if the user exists in /etc/passwd
            if id \$user > /dev/null 2>&1
                set user_home /home/\$user

                # Ensure the home directory exists
                if test -d \$user_home
                    echo \"🔧 Running 'conf pull' for user: \$user...\"

                    # Run 'conf pull' as the user
                    su -c \"conf pull\" -s /bin/bash \$user

                    echo \"✅ 'conf pull' completed for user: \$user\"
                else
                    echo \"⚠️  Skipping \$user: /home/\$user does not exist.\"
                end
            else
                echo \"⚠️  Skipping \$user: not a valid user in /etc/passwd.\"
            end
        end
    "

    echo "🎉 Finished running 'conf pull' for all cPanel users!"
end
