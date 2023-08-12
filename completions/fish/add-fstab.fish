set level1 (ls /dev | string join " ")
set level2 "ext4 ntfs vfat xfs btrfs"

complete -f -c add-fstab -n 'test_depth 1' -a $level1 -d 'Complete Device'
complete -f -c add-fstab -n 'test_depth 2' -a $level2 -d 'Complete FieSystem'
