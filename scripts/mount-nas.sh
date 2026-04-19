#!/bin/bash

source $HOME/dotfiles/globals.sh

NAS_IP="${NAS_IP:-192.168.1.100}"
MOUNT_POINT="${MOUNT_POINT:-/mnt/nas}"
SUDO_HOME=$(eval echo "~${SUDO_USER:-$USER}")
CREDS_FILE="${CREDS_FILE:-$SUDO_HOME/.nascredentials}"

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo $0"
    exit 1
fi

if [ ! -f "$CREDS_FILE" ]; then
    creds="$1"

    if [ -z "$creds" ]; then
        read -rp "NAS credentials (user:password): " creds
    fi

    if [ -z "$creds" ] || [[ "$creds" != *:* ]]; then
        echo "Invalid credentials. Provide as user:password"
        exit 1
    fi

    IFS=: read -r user pass <<<"$creds"
    printf "username=%s\npassword=%s\n" "$user" "$pass" >"$CREDS_FILE"
    chmod 600 "$CREDS_FILE"
    echo "Credentials stored in $CREDS_FILE"
fi

SHARES=$(smbclient -L "$NAS_IP" -A "$CREDS_FILE" -g 2>/dev/null | grep '^Disk|' | cut -d'|' -f2 | grep -v 'IPC\$')

if [ -z "$SHARES" ]; then
    echo "No shares found on $NAS_IP"
    exit 1
fi

ADDED=0
EXISTING=0
UID_NUM=$(id -u "$SUDO_USER")
GID_NUM=$(id -g "$SUDO_USER")

for share in $SHARES; do
    dir="$MOUNT_POINT/$share"
    mkdir -p "$dir"

    fstab_entry="//$NAS_IP/$share $dir cifs credentials=$CREDS_FILE,uid=$UID_NUM,gid=$GID_NUM,file_mode=0777,dir_mode=0777,_netdev,nofail 0 0"

    if grep -qF "//$NAS_IP/$share " /etc/fstab; then
        echo "$share: already in fstab"
        EXISTING=$((EXISTING + 1))
    else
        echo "$fstab_entry" >>/etc/fstab
        echo "$share: added to fstab"
        ADDED=$((ADDED + 1))
    fi
done

echo "Done: $ADDED added, $EXISTING already in fstab"

mount -a
echo "All shares mounted"
