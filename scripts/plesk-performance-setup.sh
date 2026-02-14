#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="/root/.plesk-perf-backups"
NGINX_CONF="/etc/nginx/nginx.conf"
MARIA_CONF="/etc/mysql/mariadb.conf.d/50-server.cnf"
MARIA_PERF="/etc/mysql/db-performance.cnf"
SYSCTL_CONF="/etc/sysctl.d/99-performance.conf"
STAMP=$(date +%Y%m%d%H%M%S)

log() { printf "\033[1;32m[+]\033[0m %s\n" "$1"; }
err() { printf "\033[1;31m[!]\033[0m %s\n" "$1" >&2; }
die() { err "$1"; exit 1; }

check_root() { [[ $EUID -eq 0 ]] || die "Must run as root"; }

backup() {
    mkdir -p "$BACKUP_DIR/$STAMP"
    for f in "$NGINX_CONF" "$MARIA_CONF" "$MARIA_PERF" "$SYSCTL_CONF"; do
        [[ -f "$f" ]] && cp "$f" "$BACKUP_DIR/$STAMP/$(basename "$f")"
    done
    sysctl -n vm.swappiness > "$BACKUP_DIR/$STAMP/swappiness.orig"
    log "Backup saved to $BACKUP_DIR/$STAMP"
}

apply_nginx() {
    log "Nginx: worker_processes -> auto"
    sed -i 's/^worker_processes\s\+[0-9]\+;/worker_processes  auto;/' "$NGINX_CONF"

    log "Nginx: enabling tcp_nopush, tcp_nodelay, gzip"
    if ! grep -q 'tcp_nopush\s\+on;' "$NGINX_CONF"; then
        sed -i '/sendfile\s\+on;/a\    tcp_nopush      on;\n    tcp_nodelay     on;' "$NGINX_CONF"
    fi

    if ! grep -q '^[[:space:]]*gzip\s\+on;' "$NGINX_CONF"; then
        sed -i '/keepalive_timeout\s\+[0-9]\+;/a\
\n    gzip             on;\
\n    gzip_vary        on;\
\n    gzip_proxied     any;\
\n    gzip_comp_level  4;\
\n    gzip_min_length  256;\
\n    gzip_types       text/plain text/css application/json application/javascript\
\n                     text/xml application/xml application/xml+rss text/javascript\
\n                     image/svg+xml application/x-font-ttf font/opentype;' "$NGINX_CONF"
    fi

    sed -i '/^[[:space:]]*#tcp_nopush/d; /^[[:space:]]*#tcp_nodelay/d; /^[[:space:]]*#gzip\b/d; /^[[:space:]]*#gzip_disable/d' "$NGINX_CONF"

    nginx -t 2>&1 || die "Nginx config test failed — restoring backup"
    systemctl reload nginx
    log "Nginx: reloaded"
}

apply_mariadb() {
    log "MariaDB: innodb_buffer_pool_size -> 512M"
    log "MariaDB: tmp_table_size, max_heap_table_size -> 64M"
    log "MariaDB: innodb_log_file_size -> 128M"

    local marker="# plesk-performance-setup managed block"

    sed -i "/^${marker}/,/^${marker} end/d" "$MARIA_CONF"
    sed -i "/^\[embedded\]/i\\
${marker}\\
innodb_buffer_pool_size = 512M\\
tmp_table_size          = 64M\\
max_heap_table_size     = 64M\\
innodb_log_file_size    = 128M\\
${marker} end\\
" "$MARIA_CONF"

    if [[ -f "$MARIA_PERF" ]]; then
        sed -i 's/^innodb_buffer_pool_size\s*=.*/innodb_buffer_pool_size = 536870912/' "$MARIA_PERF"
        sed -i 's/^innodb_log_file_size\s*=.*/innodb_log_file_size = 134217728/' "$MARIA_PERF"
    fi

    systemctl restart mariadb
    log "MariaDB: restarted"
}

apply_sysctl() {
    log "Kernel: vm.swappiness -> 10"
    printf "vm.swappiness = 10\n" > "$SYSCTL_CONF"
    sysctl -w vm.swappiness=10 >/dev/null
    log "Kernel: applied"
}

do_apply() {
    check_root
    backup
    apply_nginx
    apply_mariadb
    apply_sysctl
    log "All optimizations applied"
    show_status
}

do_revert() {
    check_root
    local target="${1:-}"

    if [[ -z "$target" ]]; then
        target=$(ls -1t "$BACKUP_DIR" 2>/dev/null | head -1)
        [[ -z "$target" ]] && die "No backups found in $BACKUP_DIR"
    fi

    local dir="$BACKUP_DIR/$target"
    [[ -d "$dir" ]] || die "Backup not found: $dir"

    log "Reverting from $dir"

    for f in "$NGINX_CONF" "$MARIA_CONF" "$MARIA_PERF"; do
        local base; base=$(basename "$f")
        [[ -f "$dir/$base" ]] && cp "$dir/$base" "$f" && log "Restored $f"
    done

    if [[ -f "$dir/swappiness.orig" ]]; then
        local orig; orig=$(cat "$dir/swappiness.orig")
        sysctl -w vm.swappiness="$orig" >/dev/null
        rm -f "$SYSCTL_CONF"
        log "Kernel: vm.swappiness -> $orig"
    fi

    nginx -t 2>&1 && systemctl reload nginx && log "Nginx: reloaded"
    systemctl restart mariadb && log "MariaDB: restarted"
    log "Revert complete"
}

show_status() {
    printf "\n\033[1;36m%-35s %s\033[0m\n" "Setting" "Value"
    printf "%-35s %s\n" "---" "---"
    printf "%-35s %s\n" "nginx worker_processes" "$(grep -oP 'worker_processes\s+\K\S+' "$NGINX_CONF" | tr -d ';')"
    printf "%-35s %s\n" "nginx gzip" "$(grep -cP '^\s*gzip\s+on;' "$NGINX_CONF" >/dev/null 2>&1 && echo on || echo off)"
    printf "%-35s %s\n" "nginx tcp_nopush" "$(grep -cP '^\s*tcp_nopush\s+on;' "$NGINX_CONF" >/dev/null 2>&1 && echo on || echo off)"
    printf "%-35s %s\n" "vm.swappiness" "$(sysctl -n vm.swappiness)"

    local pass; pass=$(cat /etc/psa/.psa.shadow 2>/dev/null) || true
    if [[ -n "$pass" ]]; then
        mysql -uadmin -p"$pass" -N -e "
            SELECT 'innodb_buffer_pool_size', CONCAT(@@innodb_buffer_pool_size / 1048576, ' MB');
            SELECT 'tmp_table_size', CONCAT(@@tmp_table_size / 1048576, ' MB');
            SELECT 'max_heap_table_size', CONCAT(@@max_heap_table_size / 1048576, ' MB');
            SELECT 'innodb_log_file_size', CONCAT(@@innodb_log_file_size / 1048576, ' MB');
        " 2>/dev/null | while IFS=$'\t' read -r k v; do
            printf "%-35s %s\n" "$k" "$v"
        done
    fi
    printf "\n"
}

list_backups() {
    [[ -d "$BACKUP_DIR" ]] || die "No backups directory"
    log "Available backups:"
    ls -1t "$BACKUP_DIR" | while read -r d; do
        printf "  %s\n" "$d"
    done
}

usage() {
    cat <<EOF
Usage: $(basename "$0") <command>

Commands:
  apply           Apply all performance optimizations
  revert [stamp]  Revert to backup (latest if no stamp given)
  status          Show current settings
  backups         List available backups
EOF
}

case "${1:-}" in
    apply)   do_apply ;;
    revert)  do_revert "${2:-}" ;;
    status)  show_status ;;
    backups) list_backups ;;
    *)       usage; exit 1 ;;
esac
