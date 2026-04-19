#!/usr/bin/env bash
set -euo pipefail

readonly USER="testbot"
readonly EMAIL="testbot@localhost.test"
readonly PASS="testbot"
readonly ROLE="administrator"

usage() {
    cat <<EOF
Usage: $(basename "$0") [--delete]

Create or delete a generic WordPress test user for local development.
Must be run from a directory containing a WordPress installation.

  (no flags)   Create user "$USER" with password "$PASS" (role: $ROLE)
  --delete     Remove the "$USER" user

Requires wp-cli.
EOF
}

main() {
    command -v wp >/dev/null 2>&1 || {
        echo "wp-cli not found" >&2
        exit 1
    }

    case "${1:-}" in
        --delete)
            wp user delete "$USER" --reassign=1 --yes 2>/dev/null &&
                echo "Deleted user '$USER'" ||
                echo "User '$USER' does not exist"
            ;;
        -h | --help)
            usage
            ;;
        "")
            if wp user get "$USER" --field=ID &>/dev/null; then
                echo "User '$USER' already exists"
            else
                wp user create "$USER" "$EMAIL" --user_pass="$PASS" --role="$ROLE"
                echo "Created user '$USER' / password '$PASS'"
            fi
            ;;
        *)
            usage >&2
            exit 1
            ;;
    esac
}

main "$@"
