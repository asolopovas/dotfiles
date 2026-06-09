#!/usr/bin/env bash
# Provision a dedicated WP test admin (random password, stored chmod 600) and, if
# playwright-cli is present, log it into wp-admin. Prints no secrets; the password
# reaches the browser only via process.env. Usage: wp-test-login.sh [wordpress-path]
set -euo pipefail
WP="${1:-$PWD}"; U=pi-test-admin
wpc() { command wp --path="$WP" "$@"; }

command -v wp >/dev/null || { echo "wp-cli not found" >&2; exit 1; }
wpc core is-installed 2>/dev/null || { echo "No WordPress at $WP" >&2; exit 1; }
HOST=$(wpc option get siteurl | sed -E 's#^https?://##; s#/.*##')
case "$HOST" in *.test|*.local|localhost|127.0.0.1) ;; *) echo "Refusing non-local host: $HOST" >&2; exit 1;; esac

PW=$(wpc eval 'echo wp_generate_password(24, true, false);')
wpc user get "$U" --field=ID >/dev/null 2>&1 \
  && wpc user update "$U" --user_pass="$PW" --role=administrator >/dev/null \
  || wpc user create "$U" "$U@example.test" --role=administrator --user_pass="$PW" >/dev/null

D="${XDG_DATA_HOME:-$HOME/.local/share}/wp-test-auth"; mkdir -p "$D"; chmod 700 "$D"
F="$D/$HOST.env"; LOGIN_URL=$(wpc eval 'echo wp_login_url();')
q() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }  # single-quote, escape quotes
(umask 177; printf 'WP_LOGIN=%s\nWP_PASSWORD=%s\nWP_LOGIN_URL=%s\n' "$(q "$U")" "$(q "$PW")" "$(q "$LOGIN_URL")" >"$F")
echo "Test user $U ready; creds in $F"

command -v playwright-cli >/dev/null || exit 0
set -a; . "$F"; set +a   # WP_LOGIN, WP_PASSWORD, WP_LOGIN_URL
playwright-cli open >/dev/null 2>&1 || true
playwright-cli goto "$WP_LOGIN_URL" >/dev/null 2>&1
SF=$(mktemp); playwright-cli snapshot --filename="$SF" >/dev/null 2>&1
ref() { grep -F "$1" "$SF" | grep -oE 'ref=e[0-9]+' | head -1 | cut -d= -f2; }
# fill takes the value as a clean shell arg (handles special chars); output suppressed
playwright-cli fill "$(ref 'textbox "Username')" "$WP_LOGIN" >/dev/null 2>&1
playwright-cli fill "$(ref 'textbox "Password')" "$WP_PASSWORD" >/dev/null 2>&1
playwright-cli click "$(ref 'button "Log In"')" >/dev/null 2>&1
rm -f "$SF"; sleep 1
URL=$(playwright-cli eval 'location.href' 2>/dev/null | awk '/^### Result/{getline; print; exit}')
case "$URL" in *wp-login.php*|*about:blank*) echo "Login check failed, URL: $URL" >&2; exit 1;; *) echo "Logged in -> wp-admin ready";; esac
