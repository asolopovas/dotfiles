#!/usr/bin/env fish

function load_env --argument env_file
    if test -f $env_file
        for line in (cat $env_file)
            if test -z (string trim -- $line)
                continue
            end

            set -l key (string match -r "^[^=]*" -- $line)
            set -l value (string sub -s (math (string length -- $key)+2) -- $line)

            if string match -qr '^[a-zA-Z_][a-zA-Z0-9_]*$' -- $key
                set -xg $key $value
            else
                echo "Invalid variable name: $key"
            end
        end
    else
        echo "Environment file $env_file does not exist, creating an empty one."
        touch $env_file
    end
end
