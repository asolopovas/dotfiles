function st
    set -l host $argv[1]

    if test -z "$host"
        echo "Usage: st <host>"
        return 1
    end

    ssh $host -t 'tmux attach || tmux new'
end
