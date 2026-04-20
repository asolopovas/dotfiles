#!/bin/bash
set -euo pipefail
source "$HOME/dotfiles/globals.sh"

VER="$(gh_latest_release redis/redis)"
SVC_USER="redis"
SVC_HOME="/var/lib/redis"
LOG_DIR="/var/log/redis"
CONF="/etc/redis/redis.conf"

[[ $EUID -eq 0 ]] && {
    echo "Don't run as root"
    exit 1
}
sudo -n true 2>/dev/null || {
    echo "Need sudo access"
    exit 1
}

if command -v redis-server &>/dev/null &&
    [[ "$(redis-server --version | grep -oE 'v=[0-9.]+' | cut -d= -f2)" == "$VER" ]]; then
    echo "Redis $VER already installed"
    exit 0
fi

echo "Installing Redis $VER..."

if command -v apt-get &>/dev/null; then
    sudo apt-get update -qq
    sudo apt-get install -y build-essential tcl pkg-config libsystemd-dev
elif command -v dnf &>/dev/null; then
    sudo dnf groupinstall -y "Development Tools"
    sudo dnf install -y tcl pkgconfig systemd-devel
elif command -v yum &>/dev/null; then
    sudo yum groupinstall -y "Development Tools"
    sudo yum install -y tcl pkgconfig systemd-devel
fi

grep -q "vm.overcommit_memory = 1" /etc/sysctl.conf 2>/dev/null ||
    echo "vm.overcommit_memory = 1" | sudo tee -a /etc/sysctl.conf >/dev/null
grep -q "net.core.somaxconn = 65535" /etc/sysctl.conf 2>/dev/null ||
    echo "net.core.somaxconn = 65535" | sudo tee -a /etc/sysctl.conf >/dev/null
sudo sysctl vm.overcommit_memory=1 net.core.somaxconn=65535 2>/dev/null || true
[[ -f /sys/kernel/mm/transparent_hugepage/enabled ]] &&
    echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled >/dev/null 2>&1 || true

id "$SVC_USER" &>/dev/null || sudo useradd --system --home "$SVC_HOME" --shell /bin/false "$SVC_USER"
sudo mkdir -p "$SVC_HOME" "$LOG_DIR" "$(dirname "$CONF")" /var/run/redis
sudo chown "$SVC_USER:$SVC_USER" "$SVC_HOME" "$LOG_DIR" /var/run/redis

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
curl -fsSL "https://github.com/redis/redis/archive/${VER}.tar.gz" | tar xz -C "$TMP"
make -C "$TMP/redis-${VER}" -j"$(nproc)" PREFIX=/usr/local
sudo make -C "$TMP/redis-${VER}" install PREFIX=/usr/local

sudo tee "$CONF" >/dev/null <<EOF
bind 127.0.0.1
port 6379
tcp-backlog 65535
timeout 300
tcp-keepalive 300
daemonize yes
pidfile /var/run/redis/redis.pid
loglevel notice
logfile $LOG_DIR/redis-server.log
databases 16
save 900 1
save 300 10
save 60 10000
stop-writes-on-bgsave-error yes
rdbcompression yes
rdbchecksum yes
dbfilename dump.rdb
dir $SVC_HOME
maxclients 10000
appendonly yes
appendfilename "appendonly.aof"
appendfsync everysec
no-appendfsync-on-rewrite no
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb
aof-load-truncated yes
aof-use-rdb-preamble yes
lua-time-limit 5000
slowlog-log-slower-than 10000
slowlog-max-len 128
latency-monitor-threshold 100
activerehashing yes
client-output-buffer-limit normal 0 0 0
client-output-buffer-limit replica 256mb 64mb 60
client-output-buffer-limit pubsub 32mb 8mb 60
hz 10
dynamic-hz yes
aof-rewrite-incremental-fsync yes
rdb-save-incremental-fsync yes
EOF

sudo tee /etc/systemd/system/redis.service >/dev/null <<EOF
[Unit]
Description=Advanced key-value store
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/bin/redis-server $CONF
Restart=always
User=$SVC_USER
Group=$SVC_USER
RuntimeDirectory=redis
RuntimeDirectoryMode=2755
UMask=007
PrivateTmp=yes
LimitNOFILE=65535
PrivateDevices=yes
ProtectHome=yes
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/security/limits.d/redis.conf >/dev/null <<EOF
$SVC_USER soft nofile 65535
$SVC_USER hard nofile 65535
$SVC_USER soft nproc 32768
$SVC_USER hard nproc 32768
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now redis.service
sleep 2

if redis-cli ping 2>/dev/null | grep -q "PONG"; then
    echo "✓ Redis $VER installed successfully"
else
    echo "✗ Redis test failed" >&2
    exit 1
fi
