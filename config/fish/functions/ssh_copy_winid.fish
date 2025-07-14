function ssh_copy_winid -a host
    set  -l data  (cat ~/.ssh/id_rsa.pub)
    ssh $host "Add-Content C:\ProgramData\ssh\administrators_authorized_keys -Value \"$data\"; icacls.exe C:\ProgramData\ssh\administrators_authorized_keys /inheritance:r /grant 'Administrators:F' /grant 'SYSTEM:F' /grant 'asolo:F'"
end


