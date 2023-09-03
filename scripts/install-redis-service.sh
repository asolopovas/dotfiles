#!/bin/bash

read -r -d '' redis_service <<-EOF
[Unit]
Description=Redis persistent key-value database
After=network.target
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/local/bin/redis-server /etc/redis/6379.conf
ExecStop=/usr/local/bin/redis-cli -p 6379 shutdown
Type=simple
User=redis
Group=redis
RuntimeDirectory=redis
RuntimeDirectoryMode=0755

[Install]
WantedBy=multi-user.target
EOF

adduser --system --group --no-create-home redis
mkdir /var/lib/redis; chown redis:redis /var/lib/redis; chmod 770 /var/lib/redis
cp $HOME/dotfiles/redis/6379.conf /etc/redis/6379.conf

echo "$redis_service" > /etc/systemd/system/redis.service
systemctl daemon-reload
systemctl enable --now redis.service

redis-cli ping
