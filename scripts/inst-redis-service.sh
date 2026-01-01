#!/bin/bash

USER="redis"
GROUP="redis"
CONFIG_DIR="/etc/redis"
CONFIG_FILE="6379.conf"
REDIS_DIR="/var/lib/redis"
REDIS_SERVER="/usr/local/bin/redis-server"
REDIS_CLI="/usr/local/bin/redis-cli"
SYSTEMD_SERVICE_FILE="/etc/systemd/system/redis.service"
PORT="6379"

# Check if user exists, add if not
if ! id "$USER" &>/dev/null; then
    adduser --system --group --no-create-home "$USER"
fi

mkdir -p "$REDIS_DIR" "$CONFIG_DIR"
chown "$USER:$GROUP" "$REDIS_DIR"
chmod 770 "$REDIS_DIR"
cp "$HOME/dotfiles/redis/$CONFIG_FILE" "$CONFIG_DIR"

cat <<EOF >"$SYSTEMD_SERVICE_FILE"
[Unit]
Description=Redis persistent key-value database
After=network.target network-online.target
Wants=network-online.target

[Service]
ExecStart=$REDIS_SERVER $CONFIG_DIR/$CONFIG_FILE
ExecStop=$REDIS_CLI -p $PORT shutdown
Type=simple
User=$USER
Group=$GROUP
RuntimeDirectory=redis
RuntimeDirectoryMode=0755

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now redis.service

$REDIS_CLI ping
