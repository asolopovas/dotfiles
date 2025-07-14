# name: default
# ---------------

# Initialize color settings at the start of the session.
set -U color_cyan (set_color cyan)
set -U color_yellow (set_color yellow)
set -U color_red (set_color red)
set -U color_blue (set_color blue)
set -U color_green (set_color green)
set -U color_brgreen (set_color brgreen)
set -U color_normal (set_color normal)

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
    set -l cwd $color_blue(pwd | sed "s:^$HOME:~:")

    # Show SSH hostname if connected via SSH
    set -l sshinfo (_ssh_info)
    if [ "$sshinfo" ]
        echo -n -s $color_cyan $sshinfo $color_normal ' '
    end

    # Display [venvname] if in a virtualenv
    if set -q VIRTUAL_ENV
        echo -n -s $color_cyan '[' (basename "$VIRTUAL_ENV") ']' $color_normal ' '
    end

    # Print pwd or full path
    echo -n -s $cwd $color_normal

    # Show git branch and status
    set -l gitinfo (_git_info)
    if [ "$gitinfo" ]
        if echo $gitinfo | grep "±" > /dev/null
            echo -n -s ' ' $color_yellow $gitinfo $color_normal
        else
            echo -n -s ' ' $color_green $gitinfo $color_normal
        end
    end

    # Display username
    echo -n -s $color_yellow ' [ ' $color_brgreen  $user $color_yellow ' ]' $color_normal

    set -l prompt_color $color_red
    if test $last_status = 0
        set prompt_color $color_normal
    end

    # Terminate with a nice prompt char
    echo -e ''
    echo -e -n -s $prompt_color '> ' $color_normal
end
