set std_cmds 'install bash fish new-wp remove-host rootssl hostssl import-rootca debug redis-monitor redis-flush'
set debug_cmds 'off develop coverage debug profile trace'
set docker_cmds_build 'build'
set docker_cmds_other 'log restart ps'
set level1 (string join ' ' $std_cmds $docker_cmds_build $docker_cmds_other)

set containers 'app log nginx mariadb redis phpmyadmin mailhog'
set no_cache ' --no-cache'
set containers_with_no_cache (string join '' $containers $no_cache)

function __fish_web_test_no_cache_command
    set -l cmd (commandline -opc)
    set -l cmd_len (count $cmd)
    if test $cmd_len -eq 3; and test $cmd[2] = 'build'
        return 0
    end
    return 1
end

complete -f -c web -n 'test_depth 1' -a $level1 -d 'Commands Completions'
complete -f -c web -n 'test_depth 2 build' -a $containers_with_no_cache -d 'Containers Completions'
complete -f -c web -n 'test_depth 2 debug' -a $debug_cmds -d 'Debug Modes'
complete -f -c web -n 'test_depth 2 ps' -a $containers -d 'Containers Completions'
complete -f -c web -n 'test_depth 2 log' -a $containers -d 'Containers Completions'
complete -f -c web -n 'test_depth 2 restart' -a $containers -d 'Containers Completions'
complete -f -c web -n '__fish_web_test_no_cache_command' -a $no_cache -d 'No-Cache argument'
