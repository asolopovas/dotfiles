set info (lsblk -nlo NAME,TYPE,SIZE | awk '/^data-root/ {print "/dev/mapper/" $1 " " $3; next} /sd.[0-9]|nvme[0-9]n[0-9]p[0-9]/ {print "/dev/" $1 " " $3}')

for line in $info
    set device (echo $line | cut -d' ' -f1)
    set size (echo $line | cut -d' ' -f2)
    complete -f -c add-fstab -n 'test_depth 1' -a $device -d $size
end

complete -f -c add-fstab -n 'test_depth 2' -a "ext4 ntfs ntfs-3g vfat xfs btrfs" -d 'Complete FileSystem'
