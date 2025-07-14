# Save this content as `timeshift.fish` and place it in ~/.config/fish/completions/

function __timeshift_needs_arg
    set cmd (commandline -opc)
    if contains -- $cmd[--comments] $cmd[--snapshot] $cmd[--target-device] $cmd[--grub-device] $cmd[--snapshot-device]
        return 1
    end
    return 0
end

complete -c timeshift -f -l check -d "Create snapshot if scheduled"
complete -c timeshift -f -l create -d "Create snapshot (even if not scheduled)"
complete -c timeshift -f -l restore -d "Restore snapshot"
complete -c timeshift -f -l delete -d "Delete snapshot"
complete -c timeshift -f -l delete-all -d "Delete all snapshots"

complete -c timeshift -f -l list -d "List snapshots or devices"
complete -c timeshift -f -l list-snapshots -d "List snapshots"
complete -c timeshift -f -l list-devices -d "List devices"
complete -c timeshift -f -l clone -d "Clone current system"

complete -c timeshift -s c -l comments -d "Set snapshot description" -xa "(__timeshift_needs_arg)"
complete -c timeshift -s t -l tags -d "Add tags to snapshot (default: O)" -xa "O B H D W M"
complete -c timeshift -s s -l snapshot -d "Specify snapshot to restore" -xa "(__timeshift_needs_arg)"
complete -c timeshift -l target-device -d "Specify target device" -xa "(__timeshift_needs_arg)"
complete -c timeshift -l grub-device -d "Specify device for installing GRUB2 bootloader" -xa "(__timeshift_needs_arg)"
complete -c timeshift -f -l skip-grub -d "Skip GRUB2 reinstall"
complete -c timeshift -l snapshot-device -d "Specify backup device (default: config)" -xa "(__timeshift_needs_arg)"

complete -c timeshift -f -l yes -d "Answer YES to all confirmation prompts"
complete -c timeshift -f -l btrfs -d "Switch to BTRFS mode (default: config)"
complete -c timeshift -f -l rsync -d "Switch to RSYNC mode (default: config)"
complete -c timeshift -f -l debug -d "Show additional debug messages"
complete -c timeshift -f -l verbose -d "Show rsync output (default)"
complete -c timeshift -f -l quiet -d "Hide rsync output"
complete -c timeshift -f -l scripted -d "Run in non-interactive mode"
complete -c timeshift -f -l help -d "Show all options"
