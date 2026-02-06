function st
    set -l host $argv[1]

    if test -z "$host"
        echo "Usage: st <host>"
        return 1
    end

    ssh $host -t 'bash -c "exec tmux new -A -s main"'
end
