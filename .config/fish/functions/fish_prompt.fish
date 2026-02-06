# name: default
# ---------------

function _git_info
    set -l branch (command git symbolic-ref HEAD 2> /dev/null | sed -e 's|^refs/heads/||')
    if [ "$branch" ]
        set -l dirty (command git status -s --ignore-submodules=dirty 2> /dev/null)
        if [ "$dirty" ]
            echo $branch "±"
        else
            echo $branch
        end
    end
end

function _ssh_info
    if set -q SSH_CONNECTION
        hostname
    end
end

function fish_prompt
    set -l last_status $status
    set -l user (whoami)
    set -l cwd (set_color blue)(pwd | sed "s:^$HOME:~:")

    # Show SSH hostname if connected via SSH
    set -l sshinfo (_ssh_info)
    if [ "$sshinfo" ]
        echo -n -s (set_color cyan) $sshinfo (set_color normal) ' '
    end

    # Display [venvname] if in a virtualenv
    if set -q VIRTUAL_ENV
        echo -n -s (set_color cyan) '[' (basename "$VIRTUAL_ENV") ']' (set_color normal) ' '
    end

    # Print pwd or full path
    echo -n -s $cwd (set_color normal)

    # Show git branch and status
    set -l gitinfo (_git_info)
    if [ "$gitinfo" ]
        if echo $gitinfo | grep "±" > /dev/null
            echo -n -s ' ' (set_color yellow) $gitinfo (set_color normal)
        else
            echo -n -s ' ' (set_color green) $gitinfo (set_color normal)
        end
    end

    # Display username
    echo -n -s (set_color yellow) ' [ ' (set_color brgreen) $user (set_color yellow) ' ]' (set_color normal)

    set -l prompt_color (set_color red)
    if test $last_status = 0
        set prompt_color (set_color normal)
    end

    # Terminate with a nice prompt char
    echo -e ''
    echo -e -n -s $prompt_color '> ' (set_color normal)
end
