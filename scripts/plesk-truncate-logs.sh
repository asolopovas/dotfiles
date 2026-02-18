#!/usr/bin/env bash
set -euo pipefail

log() { printf "\033[1;32m[+]\033[0m %s\n" "$1"; }
err() { printf "\033[1;31m[!]\033[0m %s\n" "$1" >&2; }
die() { err "$1"; exit 1; }

check_root() { [[ $EUID -eq 0 ]] || die "Must run as root"; }

DRY_RUN=false
TOTAL_FREED=0
FILE_COUNT=0

truncate_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local size
        size=$(stat -c%s "$file" 2>/dev/null || echo 0)
        if [[ "$size" -gt 0 ]]; then
            if $DRY_RUN; then
                log "[dry-run] Would truncate $file ($(numfmt --to=iec "$size"))"
            else
                : > "$file"
                log "Truncated $file (freed $(numfmt --to=iec "$size"))"
            fi
            TOTAL_FREED=$((TOTAL_FREED + size))
            FILE_COUNT=$((FILE_COUNT + 1))
        fi
    fi
}

truncate_glob() {
    local pattern="$1"
    for file in $pattern; do
        [[ -f "$file" ]] || continue
        truncate_file "$file"
    done
}

truncate_server_logs() {
    log "=== Server logs ==="

    # Nginx
    truncate_glob "/var/log/nginx/*.log"

    # Apache (Debian/Ubuntu and RHEL paths)
    truncate_glob "/var/log/apache2/*.log"
    truncate_glob "/var/log/httpd/*.log"

    # Plesk panel and service logs
    truncate_glob "/var/log/plesk/*.log"
    truncate_glob "/var/log/plesk/*_log"

    # Plesk install/update logs
    truncate_glob "/var/log/plesk/install/*.log"

    # System logs commonly growing large on web servers
    truncate_file "/var/log/syslog"
    truncate_file "/var/log/messages"
    truncate_file "/var/log/mail.log"
    truncate_file "/var/log/mail.err"
    truncate_file "/var/log/fail2ban.log"

    # MySQL / MariaDB
    truncate_file "/var/log/mysql/error.log"
    truncate_file "/var/log/mariadb/mariadb.log"
}

truncate_user_logs() {
    log "=== Plesk user logs ==="

    local vhosts_dir="/var/www/vhosts"
    [[ -d "$vhosts_dir" ]] || { err "No $vhosts_dir directory found"; return; }

    for domain_dir in "$vhosts_dir"/*/; do
        [[ -d "$domain_dir" ]] || continue

        local domain
        domain=$(basename "$domain_dir")

        # Skip system directories
        [[ "$domain" == "system" || "$domain" == "default" || "$domain" == "chroot" ]] && continue
        [[ "$domain" == .* ]] && continue

        local logs_dir="${domain_dir}logs"
        [[ -d "$logs_dir" ]] || continue

        # Domain-level access/error/proxy logs (*_log pattern)
        truncate_glob "${logs_dir}/*_log"

        # PHP error logs (domain_name.php.error.log pattern)
        truncate_glob "${logs_dir}/*.php.error.log"

        # Subdomain log directories
        for sub_dir in "$logs_dir"/*/; do
            [[ -d "$sub_dir" ]] || continue
            truncate_glob "${sub_dir}*_log"
        done

        # PHP error logs in document roots
        truncate_glob "${domain_dir}httpdocs/php_error*.log"
        truncate_file "${domain_dir}httpdocs/error_log"
        truncate_file "${domain_dir}httpdocs/error.log"

        # Laravel / framework logs
        if [[ -d "${domain_dir}httpdocs/storage/logs" ]]; then
            truncate_glob "${domain_dir}httpdocs/storage/logs/*.log"
        fi

        # WordPress debug log
        truncate_file "${domain_dir}httpdocs/wp-content/debug.log"
    done
}

truncate_php_fpm_logs() {
    log "=== PHP-FPM logs ==="

    # Plesk PHP-FPM logs for all installed PHP versions
    for php_dir in /var/log/plesk-php*-fpm/; do
        [[ -d "$php_dir" ]] || continue
        truncate_glob "${php_dir}*.log"
    done

    # System PHP-FPM
    truncate_glob "/var/log/php*-fpm.log"
    if compgen -G "/var/log/php*/" > /dev/null 2>&1; then
        for php_dir in /var/log/php*/; do
            [[ -d "$php_dir" ]] || continue
            truncate_glob "${php_dir}error.log"
        done
    fi
    truncate_glob "/var/log/php-fpm/*.log"
}

show_summary() {
    printf "\n\033[1;36m%-20s %s\033[0m\n" "Files truncated:" "$FILE_COUNT"
    printf "\033[1;36m%-20s %s\033[0m\n" "Total freed:" "$(numfmt --to=iec "$TOTAL_FREED")"
    if $DRY_RUN; then
        printf "\033[1;33m%s\033[0m\n" "(dry-run — no files were modified)"
    fi
    printf "\n"
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Truncate all Plesk server logs, PHP-FPM logs, and per-domain logs.

Options:
  --dry-run   Show what would be truncated without modifying files
  --help      Show this help message
EOF
}

main() {
    check_root

    for arg in "$@"; do
        case "$arg" in
            --dry-run) DRY_RUN=true ;;
            --help|-h) usage; exit 0 ;;
            *) err "Unknown option: $arg"; usage; exit 1 ;;
        esac
    done

    truncate_server_logs
    truncate_user_logs
    truncate_php_fpm_logs
    show_summary
}

main "$@"
