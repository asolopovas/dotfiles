#!/bin/bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
TIMEZONE="Europe/London"
DRY_RUN=false
ENABLE_NTP=true

usage() {
	cat <<EOF
Usage: $SCRIPT_NAME [--dry-run] [--no-ntp] [--timezone ZONE]

Sync Linux time for a Windows-default dual boot setup.

Defaults to Europe/London. On WSL, Linux is synced from the Windows host clock. On native Linux, Linux uses a local-time RTC so Windows can keep its default behavior.

Options:
  --dry-run       print commands without running them
  --no-ntp        skip enabling Linux network time sync
  --timezone ZONE set Linux timezone (default: Europe/London)
  -h, --help      show this help
EOF
}

log() { printf '%s\n' "$*"; }
die() {
	printf 'ERROR: %s\n' "$*" >&2
	exit 1
}

run() {
	if $DRY_RUN; then
		printf 'DRY-RUN:'
		printf ' %q' "$@"
		printf '\n'
	else
		"$@"
	fi
}

run_privileged() {
	if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
		run "$@"
	else
		command -v sudo >/dev/null || die "sudo is required for: $*"
		run sudo -- "$@"
	fi
}

is_wsl() {
	grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null || [[ -n "${WSL_INTEROP:-}" || -n "${WSL_DISTRO_NAME:-}" ]]
}

set_linux_timezone() {
	if command -v timedatectl >/dev/null; then
		run_privileged timedatectl set-timezone "$TIMEZONE"
	elif [[ -f "/usr/share/zoneinfo/$TIMEZONE" ]]; then
		run_privileged ln -snf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
	else
		die "timezone not found: $TIMEZONE"
	fi
}

sync_wsl_from_windows() {
	command -v powershell.exe >/dev/null || command -v powershell >/dev/null || die "PowerShell is required to read the Windows host clock"
	local powershell_cmd windows_utc
	if command -v powershell.exe >/dev/null; then
		powershell_cmd="powershell.exe"
	else
		powershell_cmd="powershell"
	fi
	windows_utc="$($powershell_cmd -NoProfile -Command "[DateTime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss')" | tr -d '\r' | tail -n 1)"
	[[ -n "$windows_utc" ]] || die "could not read Windows host time"
	run_privileged date -u -s "$windows_utc UTC"
	log "Linux time synced from Windows host time"
}

enable_ntp() {
	if command -v timedatectl >/dev/null; then
		run_privileged timedatectl set-ntp true
	elif command -v chronyc >/dev/null; then
		run_privileged chronyc -a makestep
	else
		log "Network time sync tool not found; skipped NTP"
	fi
}

sync_native_linux() {
	command -v timedatectl >/dev/null || die "timedatectl is required on native Linux"
	run_privileged timedatectl set-local-rtc 1
	$ENABLE_NTP && enable_ntp
	log "Linux time configured for Windows-default RTC behavior"
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--dry-run)
		DRY_RUN=true
		shift
		;;
	--no-ntp)
		ENABLE_NTP=false
		shift
		;;
	--timezone)
		TIMEZONE="${2:-}"
		[[ -n "$TIMEZONE" ]] || die "--timezone requires a value"
		shift 2
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		die "unknown option: $1"
		;;
	esac
done

set_linux_timezone
if is_wsl; then
	sync_wsl_from_windows
	$ENABLE_NTP && enable_ntp
else
	sync_native_linux
fi
