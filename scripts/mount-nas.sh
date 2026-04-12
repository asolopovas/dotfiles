#!/bin/bash

NAS_IP="${NAS_IP:-192.168.1.100}"
MOUNT_POINT="${MOUNT_POINT:-/mnt/nas}"
CREDS_FILE="${CREDS_FILE:-$HOME/.nascredentials}"

if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
    echo "Already mounted at $MOUNT_POINT"
    exit 0
fi

if [ ! -f "$CREDS_FILE" ]; then
    creds="$1"

    if [ -z "$creds" ] && [ -f "$HOME/naspass.txt" ]; then
        creds=$(head -1 "$HOME/naspass.txt")
    fi

    if [ -z "$creds" ]; then
        read -rp "NAS credentials (user:password): " creds
    fi

    if [ -z "$creds" ] || [[ "$creds" != *:* ]]; then
        echo "Invalid credentials. Provide as user:password"
        exit 1
    fi

    IFS=: read -r user pass <<< "$creds"
    printf "username=%s\npassword=%s\n" "$user" "$pass" > "$CREDS_FILE"
    chmod 600 "$CREDS_FILE"
    echo "Credentials stored in $CREDS_FILE"
fi

sudo mkdir -p "$MOUNT_POINT"
sudo chown "$(id -u):$(id -g)" "$MOUNT_POINT"

SHARES=$(smbclient -L "$NAS_IP" -A "$CREDS_FILE" -g 2>/dev/null | grep '^Disk|' | cut -d'|' -f2 | grep -v 'IPC\$')

if [ -z "$SHARES" ]; then
    echo "No shares found on $NAS_IP"
    exit 1
fi

FAILED=0
MOUNTED=0

for share in $SHARES; do
    dir="$MOUNT_POINT/$share"
    mkdir -p "$dir"

    if mountpoint -q "$dir"; then
        echo "$share: already mounted"
        MOUNTED=$((MOUNTED + 1))
        continue
    fi

    sudo mount -t cifs "//$NAS_IP/$share" "$dir" \
        -o credentials="$CREDS_FILE",uid=$(id -u),gid=$(id -g),file_mode=0777,dir_mode=0777 2>/dev/null

    if mountpoint -q "$dir"; then
        echo "$share: mounted"
        MOUNTED=$((MOUNTED + 1))
    else
        echo "$share: failed"
        rmdir "$dir" 2>/dev/null
        FAILED=$((FAILED + 1))
    fi
done

echo "Done: $MOUNTED mounted, $FAILED failed"
