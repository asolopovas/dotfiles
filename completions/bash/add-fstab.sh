_add_fstab_completion() {
    local cur_word="${COMP_WORDS[COMP_CWORD]}"
    local level1=$(ls /dev)
    local level2="ext4 ntfs vfat xfs btrfs"

    if test_depth 1; then
        COMPREPLY=( $(compgen -W "${level1}" -- "${cur_word}") )
    elif test_depth 2; then
        COMPREPLY=( $(compgen -W "${level2}" -- "${cur_word}") )
    fi
}

test_depth() {
    local depth=$1
    if [ $COMP_CWORD -eq $depth ]; then
        return 0
    fi
    return 1
}

complete -F _add_fstab_completion add-fstab
