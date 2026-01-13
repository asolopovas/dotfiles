function open_ports
    # Prompt for sudo if not running as root
    if not test (id -u) -eq 0
        echo "This function requires elevated privileges. Prompting for sudo..."
        sudo -v || return 1
    end

    # Print headers with aligned columns
    printf "%-10s %-8s %-22s %-8s %-15s %-s\n" "Proto" "State" "Local Address:Port" "PID" "Process" "Executable Path"

    # Use lsof to retrieve listening ports, PIDs, and executables
    sudo lsof -i -P -n | grep LISTEN | while read -l line
        set -l proto (echo $line | awk '{print $1}')
        set -l pid (echo $line | awk '{print $2}')
        set -l user (echo $line | awk '{print $3}')
        set -l local_addr (echo $line | awk '{print $9}')
        set -l process_name (echo $line | awk '{print $1}')

        # Retrieve executable path if possible
        set -l full_path (readlink -f /proc/$pid/exe 2>/dev/null)
        if test -z "$full_path"
            set -l full_path "[Path not found]"
        end

        # Print formatted result with PID and Process in separate columns
        printf "%-10s %-8s %-22s %-8s %-15s %-s\n" $proto "LISTEN" $local_addr $pid $process_name $full_path
    end
end
