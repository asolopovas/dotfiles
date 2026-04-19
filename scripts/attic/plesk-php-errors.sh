#!/usr/bin/env bash
set -euo pipefail

RED="\033[1;31m"
YEL="\033[1;33m"
CYN="\033[1;36m"
GRN="\033[1;32m"
DIM="\033[2m"
RST="\033[0m"

VHOSTS_DIR="/var/www/vhosts"
LINES=50
FILTER="all"
DOMAIN_FILTER=""

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Print PHP/Apache/Nginx errors and warnings from all Plesk vhost logs.

Options:
  -n NUM        Number of lines per log file (default: $LINES, 0 = all)
  -d DOMAIN     Show errors for a specific domain only
  -e            Show errors only (skip warnings)
  -w            Show warnings only (skip errors)
  -h, --help    Show this help message

Examples:
  $(basename "$0")                    # Last 50 errors+warnings per log
  $(basename "$0") -n 0              # All errors+warnings
  $(basename "$0") -d example.com    # Single domain
  $(basename "$0") -e -n 20         # Last 20 errors only
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n) LINES="$2"; shift 2 ;;
        -d) DOMAIN_FILTER="$2"; shift 2 ;;
        -e) FILTER="errors"; shift ;;
        -w) FILTER="warnings"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

[[ -d "$VHOSTS_DIR" ]] || { echo "No $VHOSTS_DIR directory found" >&2; exit 1; }

ERR_PAT="[Ee]rror|[Ff]atal|[Cc]ritical|[Ee]xception|[Pp]arse error|[Ss]yntax error"
WARN_PAT="[Ww]arning|[Nn]otice|[Dd]eprecated|[Ss]trict"

case "$FILTER" in
    errors)   GREP_PAT="$ERR_PAT" ;;
    warnings) GREP_PAT="$WARN_PAT" ;;
    all)      GREP_PAT="$ERR_PAT|$WARN_PAT" ;;
esac

colorize() {
    awk -v red="$RED" -v yel="$YEL" -v rst="$RST" '{
        line = $0
        lc = tolower(line)
        if (lc ~ /fatal|critical|exception|parse error|syntax error/) {
            printf "%s%s%s\n", red, line, rst
        } else if (lc ~ /error/) {
            printf "%s%s%s\n", red, line, rst
        } else if (lc ~ /warning|notice|deprecated|strict/) {
            printf "%s%s%s\n", yel, line, rst
        } else {
            print line
        }
    }'
}

print_header() {
    local file="$1"
    local rel="${file#"$VHOSTS_DIR"/}"
    printf "\n${CYN}━━━ %s ━━━${RST}\n" "$rel"
}

scan_log() {
    local file="$1"
    [[ -f "$file" && -s "$file" ]] || return 0

    local matches
    if [[ "$LINES" -eq 0 ]]; then
        matches=$(grep -E "$GREP_PAT" "$file" 2>/dev/null || true)
    else
        matches=$(tail -n "$((LINES * 10))" "$file" 2>/dev/null \
            | grep -E "$GREP_PAT" 2>/dev/null \
            | tail -n "$LINES" || true)
    fi

    [[ -z "$matches" ]] && return 0

    print_header "$file"
    echo "$matches" | colorize
}

scan_domain() {
    local domain_dir="$1"
    local domain
    domain=$(basename "$domain_dir")

    [[ "$domain" == "system" || "$domain" == "default" || "$domain" == "chroot" ]] && return 0
    [[ "$domain" == .* ]] && return 0
    [[ -n "$DOMAIN_FILTER" && "$domain" != "$DOMAIN_FILTER" ]] && return 0

    local logs_dir="${domain_dir}logs"

    if [[ -d "$logs_dir" ]]; then
        # Domain-level error logs
        for f in "$logs_dir"/error_log "$logs_dir"/error.log "$logs_dir"/proxy_error_log; do
            scan_log "$f"
        done

        # PHP-FPM error logs
        for f in "$logs_dir"/*.php.error.log; do
            [[ -f "$f" ]] || continue
            scan_log "$f"
        done

        # Subdomain error logs
        for sub_dir in "$logs_dir"/*/; do
            [[ -d "$sub_dir" ]] || continue
            for f in "$sub_dir"error_log "$sub_dir"error.log "$sub_dir"proxy_error_log; do
                scan_log "$f"
            done
        done
    fi

    # PHP error logs in document roots
    for docroot in "$domain_dir"httpdocs "$domain_dir"public_html; do
        [[ -d "$docroot" ]] || continue

        for f in "$docroot"/error_log "$docroot"/error.log "$docroot"/php_error.log; do
            scan_log "$f"
        done

        # Laravel logs
        if [[ -d "$docroot/storage/logs" ]]; then
            for f in "$docroot"/storage/logs/laravel*.log; do
                [[ -f "$f" ]] || continue
                scan_log "$f"
            done
        fi

        # WordPress debug log
        scan_log "$docroot/wp-content/debug.log"
    done
}

printf "${GRN}Scanning Plesk vhost error logs...${RST}\n"
printf "${DIM}Filter: %s | Lines per log: %s${RST}\n" \
    "$FILTER" "$( [[ $LINES -eq 0 ]] && echo "all" || echo "$LINES" )"

for domain_dir in "$VHOSTS_DIR"/*/; do
    [[ -d "$domain_dir" ]] || continue
    scan_domain "$domain_dir"
done

printf "\n${GRN}━━━ Done ━━━${RST}\n"
