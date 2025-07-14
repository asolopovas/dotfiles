#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "Requesting elevated privileges..."
    sudo "$0" "$@"   # Run the script as root
    exit $?
fi

apt update && apt install -y samba samba-common-bin

cp /etc/samba/smb.conf /etc/samba/smb.conf.backup

cat >> /etc/samba/smb.conf <<EOL

[WWW]
path = /home/andrius/www
read only = no
browsable = yes
guest ok = yes
create mask = 0755
EOL

# 5. Set Samba Password (Optional: Uncomment and adjust 'your_username' if you want password protection)
smbpasswd -a andrius
#sed -i 's/guest ok = yes/guest ok = no/' /etc/samba/smb.conf
sed -i '/guest ok = no/a valid users = andrius' /etc/samba/smb.conf

# 6. Restart Samba Service
systemctl restart smbd

# 7. Adjust Firewall (Optional: Uncomment if you have UFW installed and want to configure it)
ufw allow Samba
ufw enable
ufw reload

echo "Samba setup complete!"
