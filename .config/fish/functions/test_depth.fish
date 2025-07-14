function test_depth
    set -l cmd (commandline -opc)
    set -l cmd_len (count $cmd)
    set -l arg_len (count $argv)

    if test $cmd_len -eq $argv[1]
        if test $arg_len -gt 1; and not test $cmd[$cmd_len] = $argv[$arg_len];
            return 1
        end
        return 0
    end
    return 1
end
