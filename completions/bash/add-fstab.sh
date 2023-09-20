_add_fstab_completion() {
    local cur_word="${COMP_WORDS[COMP_CWORD]}"

    # Get devices and sizes similarly to how the Fish script does
    local info=$(lsblk -nlo NAME,TYPE,SIZE | awk '/^data-root/ {print "/dev/mapper/" $1; next} /sd.[0-9]|nvme[0-9]n[0-9]p[0-9]/ {print "/dev/" $1}')
    local level2="ext4 ntfs ntfs-3g vfat xfs btrfs"

    if test_depth 1; then
        COMPREPLY=( $(compgen -W "${info}" -- "${cur_word}") )
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
