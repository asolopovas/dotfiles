
function __web_debug
    set -l file "$BASH_COMP_DEBUG_FILE"
    if test -n "$file"
        echo "$argv" >> $file
    end
end

function __web_perform_completion
    __web_debug "Starting __web_perform_completion"

    set -l args (commandline -opc)
    set -l lastArg (string escape -- (commandline -ct))

    __web_debug "args: $args"
    __web_debug "last arg: $lastArg"

    set -l requestComp "WEB_ACTIVE_HELP=0 $args[1] __complete $args[2..-1] $lastArg"

    __web_debug "Calling $requestComp"
    set -l results (eval $requestComp 2> /dev/null)

    for line in $results[-1..1]
        if test (string trim -- $line) = ""
            set results $results[1..-2]
        else
            break
        end
    end

    set -l comps $results[1..-2]
    set -l directiveLine $results[-1]

    set -l flagPrefix (string match -r -- '-.*=' "$lastArg")

    __web_debug "Comps: $comps"
    __web_debug "DirectiveLine: $directiveLine"
    __web_debug "flagPrefix: $flagPrefix"

    for comp in $comps
        printf "%s%s\n" "$flagPrefix" "$comp"
    end

    printf "%s\n" "$directiveLine"
end

function __web_perform_completion_once
    __web_debug "Starting __web_perform_completion_once"

    if test -n "$__web_perform_completion_once_result"
        __web_debug "Seems like a valid result already exists, skipping __web_perform_completion"
        return 0
    end

    set --global __web_perform_completion_once_result (__web_perform_completion)
    if test -z "$__web_perform_completion_once_result"
        __web_debug "No completions, probably due to a failure"
        return 1
    end

    __web_debug "Performed completions and set __web_perform_completion_once_result"
    return 0
end

function __web_clear_perform_completion_once_result
    __web_debug ""
    __web_debug "========= clearing previously set __web_perform_completion_once_result variable =========="
    set --erase __web_perform_completion_once_result
    __web_debug "Successfully erased the variable __web_perform_completion_once_result"
end

function __web_requires_order_preservation
    __web_debug ""
    __web_debug "========= checking if order preservation is required =========="

    __web_perform_completion_once
    if test -z "$__web_perform_completion_once_result"
        __web_debug "Error determining if order preservation is required"
        return 1
    end

    set -l directive (string sub --start 2 $__web_perform_completion_once_result[-1])
    __web_debug "Directive is: $directive"

    set -l shellCompDirectiveKeepOrder 32
    set -l keeporder (math (math --scale 0 $directive / $shellCompDirectiveKeepOrder) % 2)
    __web_debug "Keeporder is: $keeporder"

    if test $keeporder -ne 0
        __web_debug "This does require order preservation"
        return 0
    end

    __web_debug "This doesn't require order preservation"
    return 1
end


function __web_prepare_completions
    __web_debug ""
    __web_debug "========= starting completion logic =========="

    set --erase __web_comp_results

    __web_perform_completion_once
    __web_debug "Completion results: $__web_perform_completion_once_result"

    if test -z "$__web_perform_completion_once_result"
        __web_debug "No completion, probably due to a failure"
        return 1
    end

    set -l directive (string sub --start 2 $__web_perform_completion_once_result[-1])
    set --global __web_comp_results $__web_perform_completion_once_result[1..-2]

    __web_debug "Completions are: $__web_comp_results"
    __web_debug "Directive is: $directive"

    set -l shellCompDirectiveError 1
    set -l shellCompDirectiveNoSpace 2
    set -l shellCompDirectiveNoFileComp 4
    set -l shellCompDirectiveFilterFileExt 8
    set -l shellCompDirectiveFilterDirs 16

    if test -z "$directive"
        set directive 0
    end

    set -l compErr (math (math --scale 0 $directive / $shellCompDirectiveError) % 2)
    if test $compErr -eq 1
        __web_debug "Received error directive: aborting."
        return 1
    end

    set -l filefilter (math (math --scale 0 $directive / $shellCompDirectiveFilterFileExt) % 2)
    set -l dirfilter (math (math --scale 0 $directive / $shellCompDirectiveFilterDirs) % 2)
    if test $filefilter -eq 1; or test $dirfilter -eq 1
        __web_debug "File extension filtering or directory filtering not supported"
        return 1
    end

    set -l nospace (math (math --scale 0 $directive / $shellCompDirectiveNoSpace) % 2)
    set -l nofiles (math (math --scale 0 $directive / $shellCompDirectiveNoFileComp) % 2)

    __web_debug "nospace: $nospace, nofiles: $nofiles"

    if test $nospace -ne 0; or test $nofiles -eq 0
        set -l prefix (commandline -t | string escape --style=regex)
        __web_debug "prefix: $prefix"

        set -l completions (string match -r -- "^$prefix.*" $__web_comp_results)
        set --global __web_comp_results $completions
        __web_debug "Filtered completions are: $__web_comp_results"

        set -l numComps (count $__web_comp_results)
        __web_debug "numComps: $numComps"

        if test $numComps -eq 1; and test $nospace -ne 0
            set -l split (string split --max 1 \t $__web_comp_results[1])

            set -l lastChar (string sub -s -1 -- $split)
            if not string match -r -q "[@=/:.,]" -- "$lastChar"
                __web_debug "Adding second completion to perform nospace directive"
                set --global __web_comp_results $split[1] $split[1].
                __web_debug "Completions are now: $__web_comp_results"
            end
        end

        if test $numComps -eq 0; and test $nofiles -eq 0
            __web_debug "Requesting file completion"
            return 1
        end
    end

    return 0
end

if type -q "web"
    complete --do-complete "web " > /dev/null 2>&1
end

complete -c web -e

complete -c web -n '__web_clear_perform_completion_once_result'
complete -c web -n 'not __web_requires_order_preservation && __web_prepare_completions' -f -a '$__web_comp_results'
complete -k -c web -n '__web_requires_order_preservation && __web_prepare_completions' -f -a '$__web_comp_results'
