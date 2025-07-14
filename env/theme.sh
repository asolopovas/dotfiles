# Initialize color settings at the start of the session.
color_cyan="\e[36m"
color_yellow="\e[93m"
color_red="\e[91m"
color_blue="\e[34m"
color_green="\e[32m"
color_brgreen="\e[92m"
color_normal="\e[0m"
color_white="\e[97m"

_git_info() {
    local branch
    branch=$(git symbolic-ref HEAD 2>/dev/null | sed -e 's|^refs/heads/||')
    if [[ $branch ]]; then
        local dirty
        dirty=$(git status -s --ignore-submodules=dirty 2>/dev/null)
        if [[ $dirty ]]; then
            echo "$branch ±"
        else
            echo "$branch"
        fi
    fi
}

_ssh_info() {
    [ "$SSH_TTY" ] && hostname
}

trap '_start_time=$(date +%s%N)' DEBUG

_omb_theme_PROMPT_COMMAND() {

    local last_status=$?
    local user=$(whoami)
    local cwd="${color_blue}$(pwd | sed "s:^$HOME:~:")${color_normal}"
    local sshinfo=$(_ssh_info)
    local gitinfo=$(_git_info)

    PS1="${color_brgreen}<bash> "
    if [[ $sshinfo ]]; then
        PS1+="${color_cyan}${sshinfo}${color_normal} "
    fi
    PS1+="$cwd"

    # Check if gitinfo has any content before appending.
    if [[ -n $gitinfo ]]; then
        if [[ $gitinfo =~ "±" ]]; then
            PS1+=" ${color_yellow}${gitinfo}${color_normal}"
        else
            PS1+=" ${color_green}${gitinfo}${color_normal}"
        fi
    fi

    PS1+=" ${color_yellow}[ ${color_brgreen}${user}${color_yellow} ]${color_normal} "

    if [[ $last_status -eq 0 ]]; then
        PS1+="\n${color_normal}> "
    else
        PS1+="\n${color_red}> ${color_normal}"
    fi
}

PROMPT_COMMAND="_omb_theme_PROMPT_COMMAND"
