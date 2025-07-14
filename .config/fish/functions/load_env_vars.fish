function load_env_vars
    set -l env_file $argv[1]
    if test -f $env_file
        for line in (cat $env_file)
            set -l trimmed_line (string trim -- $line)
            if test -z "$trimmed_line"
                continue
            end

            set -l key (echo $trimmed_line | cut -d '=' -f 1)
            set -l value (echo $trimmed_line | cut -d '=' -f 2-)

            if not set -q $key
                set -gx $key $value
            end
        end
    else
        echo "File does not exist: $env_file"
    end
end
