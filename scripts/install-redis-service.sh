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

echo "$redis_service" > /etc/systemd/system/redis.service
systemctl daemon-reload
systemctl enable --now redis.service
