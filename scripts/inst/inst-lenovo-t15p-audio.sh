#!/usr/bin/env bash
set -Eeuo pipefail

APP_ID="com.github.wwmm.easyeffects"
DRIVER_URL="https://download.lenovo.com/pccbbs/mobiles/n3ea121w.exe"
DRIVER_SHA256="934c1e2dcb30cc34e69f3daee42ee5612992caad29e03802be221bcbc443f687"
CONVERTER_URL="https://raw.githubusercontent.com/antoinecellerier/speaker-tuning-to-easyeffects/main/dolby_to_easyeffects.py"
WORK_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/lenovo-t15p-audio"
EE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/easyeffects"
EE_FLATPAK_DIR="$HOME/.var/app/$APP_ID/data/easyeffects"
SUBSYSTEM_ID="${SUBSYSTEM_ID:-}"
PIPEWIRE=false
ROLLBACK=false
TEST_SOUND=false

log() { printf '\033[1;32m==>\033[0m %s\n' "$*" >&2; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
die() {
    printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2
    exit 1
}
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Install Lenovo ThinkPad T15p Gen 3 Dolby/EasyEffects audio presets.
By default this is safe: installs/generates presets but does not switch audio stack.

Options:
  --pipewire        Also switch PulseAudio to PipeWire-Pulse and enable EasyEffects
  --rollback        Disable PipeWire-Pulse/EasyEffects and restore PulseAudio
  --test            Play a short speaker test after setup
  --subsystem ID    Override detected Lenovo audio subsystem, e.g. 17AA22F5
  -h, --help        Show help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --pipewire) PIPEWIRE=true ;;
        --rollback) ROLLBACK=true ;;
        --test) TEST_SOUND=true ;;
        --subsystem)
            SUBSYSTEM_ID="${2:?missing subsystem id}"
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *) die "Unknown option: $1" ;;
    esac
    shift
done

install_apt() {
    local missing=()
    for pkg in "$@"; do dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg"); done
    ((${#missing[@]} == 0)) && return 0
    log "Installing packages: ${missing[*]}"
    sudo apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${missing[@]}"
}

restore_pulseaudio() {
    log "Restoring PulseAudio output"
    flatpak kill "$APP_ID" >/dev/null 2>&1 || true
    pkill -f easyeffects >/dev/null 2>&1 || true
    systemctl --user --now disable pipewire-pulse.service pipewire-pulse.socket wireplumber.service >/dev/null 2>&1 || true
    systemctl --user unmask pulseaudio.service pulseaudio.socket >/dev/null 2>&1 || true
    systemctl --user --now enable pulseaudio.service pulseaudio.socket >/dev/null 2>&1 || true
    pulseaudio -k >/dev/null 2>&1 || true
    sleep 2
    set_speaker || true
    pactl info | grep -E 'Server Name|Default Sink' || true
}

set_speaker() {
    local sink="alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__hw_sofhdadsp__sink"
    pactl set-default-sink "$sink" 2>/dev/null || true
    pactl set-sink-port "$sink" '[Out] Speaker' 2>/dev/null || true
    pactl set-sink-mute "$sink" 0 2>/dev/null || true
    pactl set-sink-volume "$sink" 90% 2>/dev/null || true
    amixer -q -c 0 sset 'Auto-Mute Mode' Disabled 2>/dev/null || true
    amixer -q -c 0 sset Master 100% unmute 2>/dev/null || true
    amixer -q -c 0 sset Speaker 100% unmute 2>/dev/null || true
}

detect_subsystem() {
    [[ -n "$SUBSYSTEM_ID" ]] && {
        printf '%s\n' "${SUBSYSTEM_ID^^}"
        return
    }
    local id
    id=$(grep -h 'Subsystem Id:' /proc/asound/card*/codec#* 2>/dev/null |
        awk '/0x17aa/{print "17AA" toupper(substr($3,7)); exit}')
    [[ -n "$id" ]] || die "Could not detect Lenovo audio subsystem; pass --subsystem 17AA22F5"
    printf '%s\n' "$id"
}

install_easyeffects() {
    if flatpak list --app 2>/dev/null | grep -q "$APP_ID"; then
        log "EasyEffects already installed"
        return
    fi
    log "Installing EasyEffects Flatpak"
    flatpak remote-list | awk '{print $1}' | grep -qx flathub ||
        flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install -y flathub "$APP_ID"
}

download_assets() {
    mkdir -p "$WORK_DIR"
    local exe="$WORK_DIR/n3ea121w.exe"
    if [[ ! -f "$exe" ]] || ! printf '%s  %s\n' "$DRIVER_SHA256" "$exe" | sha256sum -c --status; then
        log "Downloading Lenovo Realtek/Dolby driver"
        curl -fL --retry 3 -o "$exe" "$DRIVER_URL"
        printf '%s  %s\n' "$DRIVER_SHA256" "$exe" | sha256sum -c --status || die "Lenovo driver checksum mismatch"
    fi
    [[ -f "$WORK_DIR/dolby_to_easyeffects.py" ]] || curl -fL -o "$WORK_DIR/dolby_to_easyeffects.py" "$CONVERTER_URL"
}

extract_xml() {
    local sid="$1" extract="$WORK_DIR/extracted" xml
    if [[ ! -d "$extract" ]]; then
        log "Extracting Lenovo driver"
        innoextract -q -e "$WORK_DIR/n3ea121w.exe" -d "$extract" >/dev/null
    fi
    xml=$(find "$extract" -type f -iname "DEV_0257_SUBSYS_${sid}_PCI_SUBSYS_*.xml" ! -iname '*settings*' | head -n 1)
    [[ -n "$xml" ]] || die "No Dolby tuning XML found for $sid"
    cp -f "$xml" "$WORK_DIR/$(basename "$xml")"
    printf '%s\n' "$xml"
}

generate_presets() {
    local xml="$1" target
    for target in "$EE_DIR" "$EE_FLATPAK_DIR"; do
        mkdir -p "$target/output" "$target/irs"
        log "Generating presets in $target"
        python3 "$WORK_DIR/dolby_to_easyeffects.py" --all-profiles --prefix T15p-Clear --disable mbc \
            --output-dir "$target/output" --irs-dir "$target/irs" "$xml" >/dev/null
        python3 "$WORK_DIR/dolby_to_easyeffects.py" --all-profiles --prefix T15p-Dolby \
            --output-dir "$target/output" --irs-dir "$target/irs" "$xml" >/dev/null
    done
}

switch_pipewire() {
    warn "PipeWire-Pulse may be worse on this Mint 21.3/5.15 setup; rollback with: $0 --rollback"
    install_apt pipewire-pulse wireplumber libspa-0.2-bluetooth pipewire-audio-client-libraries
    systemctl --user --now disable pulseaudio.service pulseaudio.socket >/dev/null 2>&1 || true
    systemctl --user mask pulseaudio.service pulseaudio.socket >/dev/null 2>&1 || true
    pulseaudio -k >/dev/null 2>&1 || true
    systemctl --user --now enable pipewire.service pipewire.socket pipewire-pulse.service pipewire-pulse.socket wireplumber.service
    systemctl --user restart pipewire wireplumber pipewire-pulse
    sleep 3
    set_speaker
    flatpak run "$APP_ID" --gapplication-service >/tmp/easyeffects.log 2>&1 &
    disown || true
}

play_test() {
    local wav=/usr/share/sounds/alsa/Front_Center.wav
    [[ -f "$wav" ]] || return 0
    log "Playing test sound"
    paplay "$wav" || true
}

main() {
    if $ROLLBACK; then
        restore_pulseaudio
        exit 0
    fi
    [[ "$(uname -s)" == Linux ]] || die "Linux only"
    install_apt curl ca-certificates flatpak innoextract python3 python3-numpy python3-scipy pulseaudio-utils alsa-utils
    download_assets
    install_easyeffects
    local sid xml
    sid=$(detect_subsystem)
    log "Using audio subsystem $sid"
    xml=$(extract_xml "$sid")
    generate_presets "$xml"
    $PIPEWIRE && switch_pipewire || {
        log "Leaving current audio stack unchanged"
        set_speaker
    }
    $TEST_SOUND && play_test
    log "Done. Open EasyEffects and try: T15p-Clear-Dynamic-Balanced"
}

main "$@"
