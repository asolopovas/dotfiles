#!/bin/bash
set -Eeuo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
# shellcheck disable=SC1091
source "$DOTFILES_DIR/globals.sh"

APP_ID="com.rtosta.zapzap"
APP_NAME="ZapZap"
REMOTE_NAME="flathub"
REMOTE_URL="https://dl.flathub.org/repo/flathub.flatpakrepo"
SCOPE="${SCOPE:-system}"
FORCE="${FORCE:-false}"

if [[ "${EUID}" -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
else
    SUDO=""
fi
export SUDO

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Install ${APP_NAME} (${APP_ID}) from Flathub.

Options:
  --user       Install for current user only
  --system     Install system-wide (default)
  --force      Reinstall even if already installed
  -h, --help   Show this help
EOF
}

log_info() { print_color green "$*"; }
log_warn() { print_color yellow "$*"; }
log_error() { print_color red "$*" >&2; }

run_root() {
    if [[ "${EUID}" -eq 0 ]]; then
        "$@"
    elif [[ -n "${SUDO}" ]]; then
        "$SUDO" "$@"
    else
        log_error "Root privileges required, but sudo is not available."
        return 1
    fi
}

install_flatpak() {
    if cmd_exist flatpak; then
        return 0
    fi

    log_info "Installing Flatpak..."
    pkg_install flatpak
}

flatpak_scope_arg() {
    case "$SCOPE" in
        user) printf '%s\n' "--user" ;;
        system) printf '%s\n' "--system" ;;
        *)
            log_error "Invalid scope: $SCOPE (expected: user or system)"
            return 1
            ;;
    esac
}

flatpak_root_prefix() {
    if [[ "$SCOPE" == "system" && "${EUID}" -ne 0 && -n "${SUDO}" ]]; then
        printf '%s\n' "$SUDO"
    fi
}

ensure_flathub() {
    local scope_arg
    scope_arg="$(flatpak_scope_arg)"

    if flatpak remotes "$scope_arg" --columns=name | grep -Fxq "$REMOTE_NAME"; then
        return 0
    fi

    log_info "Adding Flathub remote (${SCOPE})..."
    if [[ "$SCOPE" == "system" ]]; then
        run_root flatpak remote-add --if-not-exists "$scope_arg" "$REMOTE_NAME" "$REMOTE_URL"
    else
        flatpak remote-add --if-not-exists "$scope_arg" "$REMOTE_NAME" "$REMOTE_URL"
    fi
}

is_installed() {
    local scope_arg
    scope_arg="$(flatpak_scope_arg)"
    flatpak list "$scope_arg" --app --columns=application | grep -Fxq "$APP_ID"
}

install_zapzap() {
    local scope_arg root_prefix
    scope_arg="$(flatpak_scope_arg)"
    root_prefix="$(flatpak_root_prefix)"

    if [[ "$FORCE" != true ]] && is_installed; then
        log_info "$APP_NAME already installed for ${SCOPE} — skipping (use --force to reinstall)."
        return 0
    fi

    log_info "Installing $APP_NAME from Flathub (${SCOPE})..."
    if [[ -n "$root_prefix" ]]; then
        "$root_prefix" flatpak install -y "$scope_arg" "$REMOTE_NAME" "$APP_ID"
    else
        flatpak install -y "$scope_arg" "$REMOTE_NAME" "$APP_ID"
    fi
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --user)
                SCOPE="user"
                shift
                ;;
            --system)
                SCOPE="system"
                shift
                ;;
            --force)
                FORCE="true"
                shift
                ;;
            -h | --help)
                usage
                return 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage >&2
                return 1
                ;;
        esac
    done

    install_flatpak
    ensure_flathub
    install_zapzap

    log_info "$APP_NAME installed. Launch with: flatpak run $APP_ID"
}

main "$@"
