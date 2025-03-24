function __st_hosts
    grep '^Host ' ~/.ssh/config | awk '{print $2}'
end

complete -c st -a "(__st_hosts)"
