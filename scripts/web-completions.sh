# File: /etc/bash_completion.d/web

_web()
{
    local cur prev words cword
    _init_completion -n : || return

    local commands="install bash fish build-webconf build restart ps new-wp remove-host rootssl hostssl import-rootca"
    local options="--no-cache"

    if [[ ${cur} == -* ]] ; then
        COMPREPLY=($(compgen -W "${options}" -- ${cur}))
        return 0
    fi

    case ${prev} in
        web)
            COMPREPLY=($(compgen -W "${commands}" -- ${cur}))
            return 0
            ;;
        build|ps)
            local services="app"
            COMPREPLY=($(compgen -W "${services}" -- ${cur}))
            return 0
            ;;
        new-wp|remove-host|hostssl)
            local domains="example.com"
            COMPREPLY=($(compgen -W "${domains}" -- ${cur}))
            return 0
            ;;
    esac
}

complete -F _web web

