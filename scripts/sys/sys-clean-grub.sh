#!/bin/bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
KEEP_COUNT=2
DRY_RUN=false
RUN_AUTOREMOVE=true
UPDATE_GRUB=true
ORIG_ARGS=("$@")

usage() {
	echo "Usage: $SCRIPT_NAME [--keep N] [--dry-run] [--no-autoremove] [--no-update-grub]"
}

log() { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die() {
	printf 'ERROR: %s\n' "$*" >&2
	exit 1
}
run() { if $DRY_RUN; then
	printf 'DRY-RUN:'
	printf ' %q' "$@"
	printf '\n'
else "$@"; fi; }

while [[ $# -gt 0 ]]; do
	case "$1" in
	-k | --keep)
		KEEP_COUNT="${2:?}"
		shift 2
		;;
	-n | --dry-run)
		DRY_RUN=true
		shift
		;;
	--no-autoremove)
		RUN_AUTOREMOVE=false
		shift
		;;
	--no-update-grub)
		UPDATE_GRUB=false
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*) die "unknown option: $1" ;;
	esac
done

[[ "$KEEP_COUNT" =~ ^[0-9]+$ && "$KEEP_COUNT" -ge 1 ]] || die "--keep must be >= 1"
[[ "${EUID:-$(id -u)}" -eq 0 ]] || exec sudo -- "$0" "${ORIG_ARGS[@]}"
command -v dpkg-query >/dev/null || die "dpkg-query not found"
command -v apt-get >/dev/null || die "apt-get not found"

set_var() {
	local file="$1" key="$2" value="$3" escaped
	escaped="$(printf '%s' "$key" | sed 's/[][\/.*^$]/\\&/g')"
	[[ -e "$file" ]] || run install -m 0644 /dev/null "$file"
	if grep -qE "^${escaped}=" "$file"; then
		run sed -i "s|^${escaped}=.*|${key}=${value}|" "$file"
	elif $DRY_RUN; then
		log "DRY-RUN: append ${key}=${value} to $file"
	else
		printf '%s=%s\n' "$key" "$value" >>"$file"
	fi
}

win_uuid() {
	local dev path
	if command -v os-prober >/dev/null; then
		dev="$(os-prober 2>/dev/null | awk -F'[@:]' '/Windows/ {print $1; exit}' || true)"
		[[ -n "${dev:-}" ]] && blkid -s UUID -o value "$dev" 2>/dev/null && return 0
	fi
	for path in /boot/efi/EFI/Microsoft/Boot/bootmgfw.efi /efi/Microsoft/Boot/bootmgfw.efi; do
		[[ -e "$path" ]] || continue
		dev="$(findmnt -no SOURCE -T "$path" 2>/dev/null || true)"
		[[ -n "${dev:-}" ]] && blkid -s UUID -o value "$dev" 2>/dev/null && return 0
	done
}

kernel_name() {
	local pkg="$1"
	pkg="${pkg#linux-image-unsigned-}"
	printf '%s\n' "${pkg#linux-image-}"
}

kernel_pkgs() {
	local kernel="$1" base="${1%-generic}"
	dpkg-query -W -f='${Package}\n' 'linux-*' 2>/dev/null | awk -v k="$kernel" -v b="$base" 'index($0,k) || index($0,b)' | sort -u
}

run cp -a /etc/default/grub "/etc/default/grub.bak.$(date +%Y%m%d-%H%M%S)"
run mkdir -p /etc/default/grub.d
set_var /etc/default/grub GRUB_DEFAULT saved
set_var /etc/default/grub GRUB_SAVEDEFAULT true
set_var /etc/default/grub GRUB_TIMEOUT_STYLE menu
set_var /etc/default/grub GRUB_TIMEOUT 5
set_var /etc/default/grub GRUB_DISABLE_SUBMENU false
[[ -f /etc/default/grub.d/50_linuxmint.cfg ]] && set_var /etc/default/grub.d/50_linuxmint.cfg GRUB_DISABLE_OS_PROBER false

WINDOWS_UUID="$(win_uuid || true)"
if [[ -n "$WINDOWS_UUID" ]]; then
	if $DRY_RUN; then
		log "DRY-RUN: write /etc/grub.d/06_windows for Windows EFI UUID $WINDOWS_UUID"
	else
		cat >/etc/grub.d/06_windows <<EOF
#!/bin/sh
exec tail -n +3 \$0

menuentry "Windows 11" --class windows --class os \$menuentry_id_option 'osprober-efi-${WINDOWS_UUID}' {
	savedefault
	insmod part_gpt
	insmod fat
	search --no-floppy --fs-uuid --set=root ${WINDOWS_UUID}
	chainloader /efi/Microsoft/Boot/bootmgfw.efi
}
EOF
		chmod +x /etc/grub.d/06_windows
	fi
	set_var /etc/default/grub.d/50_linuxmint.cfg GRUB_OS_PROBER_SKIP_LIST "\"${WINDOWS_UUID}@/efi/Microsoft/Boot/bootmgfw.efi\""
else
	warn "Windows EFI not detected"
fi

CURRENT_KERNEL="$(uname -r)"
mapfile -t IMAGE_PACKAGES < <(dpkg-query -W -f='${Package}\n' 'linux-image-[0-9]*' 2>/dev/null | sort -Vr || true)
declare -A KEEPERS SEEN
declare -a OLD_KERNELS=() PURGE_PACKAGES=()
KEPT=0
KEEPERS["$CURRENT_KERNEL"]=1
for PACKAGE in "${IMAGE_PACKAGES[@]}"; do
	KERNEL="$(kernel_name "$PACKAGE")"
	[[ "$KEPT" -ge "$KEEP_COUNT" ]] && continue
	KEEPERS["$KERNEL"]=1
	KEPT=$((KEPT + 1))
done
for PACKAGE in "${IMAGE_PACKAGES[@]}"; do
	KERNEL="$(kernel_name "$PACKAGE")"
	[[ -n "${KEEPERS[$KERNEL]:-}" ]] && continue
	OLD_KERNELS+=("$KERNEL")
	while read -r DEP; do
		[[ -n "$DEP" && -z "${SEEN[$DEP]:-}" ]] || continue
		PURGE_PACKAGES+=("$DEP")
		SEEN["$DEP"]=1
	done < <(kernel_pkgs "$KERNEL")
done

log "Running kernel: $CURRENT_KERNEL"
log "Keeping: ${!KEEPERS[*]}"
if ((${#OLD_KERNELS[@]})); then
	log "Removing: ${OLD_KERNELS[*]}"
	((${#PURGE_PACKAGES[@]} == 0)) || run apt-get purge -y "${PURGE_PACKAGES[@]}"
else
	log "No old kernels to remove"
fi
$RUN_AUTOREMOVE && run apt-get autoremove --purge -y
$UPDATE_GRUB && run update-grub

find /boot -maxdepth 1 -type f \( -name 'vmlinuz-*' -o -name 'initrd.img-*' \) -printf '%f\n' 2>/dev/null | sort
