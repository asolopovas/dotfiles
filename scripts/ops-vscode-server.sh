#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------------------
# VS Code Server operational commands.
# Manages /opt/vscode-server (shared across all Plesk vhosts via symlink).
#
# Initial setup is handled by plesk-init.sh (setup_vscode + vhost symlinks).
# This script handles ongoing operations: update, extensions, cleanup.
# ---------------------------------------------------------------------------

SHARED="/opt/vscode-server"
VHOSTS="/var/www/vhosts"
GROUP="psacln"
KEEP=2

log()   { printf '\033[32m[vscode-server]\033[0m %s\n' "$*"; }
warn()  { printf '\033[33m[vscode-server]\033[0m %s\n' "$*" >&2; }
error() { printf '\033[31m[vscode-server]\033[0m %s\n' "$*" >&2; exit 1; }
need_root() { [[ $EUID -eq 0 ]] || error "Must run as root"; }

fix_perms() {
    chgrp -R "$GROUP" "$SHARED"
    find "$SHARED" -type d -exec chmod 2775 {} +
    find "$SHARED" -type f -exec chmod 664 {} +
    find "$SHARED" -type f \( -name "code-*" -o -name "code" -o -name "node" \
        -o -name "*.sh" -o -path "*/bin/*" -o -path "*/.bin/*" \) -exec chmod 775 {} +
}

rebuild_ext_json() {
    local jf="$SHARED/extensions/extensions.json"
    [[ -f "$jf" ]] || return 0
    python3 -c "
import json,os
d='$SHARED/extensions'
with open('$jf') as f: exts=json.load(f)
for e in exts:
    r=e.get('relativeLocation','')
    if r: e['location']={'\$mid':1,'path':os.path.join(d,r),'scheme':'file'}
with open('$jf','w') as f: json.dump(exts,f)
" 2>/dev/null || warn "python3 failed fixing extensions.json"
}

cmd_update() {
    need_root
    [[ -d "$SHARED" ]] || error "Run 'setup' first"
    log "Checking latest version..."

    local commit; commit=$(curl -fsSL \
        "https://update.code.visualstudio.com/api/latest/server-linux-x64/stable" \
        2>/dev/null | python3 -c "import sys,json;print(json.load(sys.stdin)['version'])") \
        || error "Failed to fetch latest commit"

    if [[ -d "$SHARED/cli/servers/Stable-$commit" ]]; then
        log "Server already up to date"
    else
        log "Downloading $commit..."
        local tmp; tmp=$(mktemp -d); trap "rm -rf '$tmp'" EXIT

        curl -fsSL "https://update.code.visualstudio.com/commit:$commit/server-linux-x64/stable" \
            -o "$tmp/server.tar.gz" || error "Download failed"
        mkdir -p "$tmp/x" && tar -xzf "$tmp/server.tar.gz" -C "$tmp/x"
        local ex; ex=$(ls -1d "$tmp/x"/*/ | head -1)
        mkdir -p "$SHARED/cli/servers/Stable-$commit"
        mv "$ex" "$SHARED/cli/servers/Stable-$commit/server"

        if curl -fsSL "https://update.code.visualstudio.com/commit:$commit/cli-linux-x64/stable" \
            -o "$tmp/cli.tar.gz" 2>/dev/null; then
            tar -xzf "$tmp/cli.tar.gz" -C "$tmp/" 2>/dev/null
            [[ -f "$tmp/code" ]] && mv "$tmp/code" "$SHARED/code-$commit"
        fi

        fix_perms
        trap - EXIT; rm -rf "$tmp"
    fi

    cmd_update_ext
    log "Update complete"
}

latest_code_server() {
    local srv; srv=$(ls -1dt "$SHARED"/cli/servers/Stable-*/server 2>/dev/null | head -1)
    [[ -n "$srv" ]] || error "No server found"
    echo "$srv/bin/code-server"
}

cmd_install_ext() {
    need_root
    [[ -d "$SHARED" ]] || error "Run 'setup' first"
    local id="${1:-}"; [[ -n "$id" ]] || error "Usage: $0 install-ext <extension-id>"
    "$(latest_code_server)" --extensions-dir "$SHARED/extensions" \
        --install-extension "$id" --force 2>&1 || warn "Install may have failed"
    rebuild_ext_json && fix_perms
    log "Extension installed"
}

cmd_update_ext() {
    need_root
    [[ -d "$SHARED" ]] || error "Run 'setup' first"
    log "Updating all extensions..."
    "$(latest_code_server)" --extensions-dir "$SHARED/extensions" \
        --update-extensions 2>&1 || warn "Some extensions may have failed to update"
    rebuild_ext_json && fix_perms
    log "Extensions updated"
}

cmd_status() {
    if [[ -d "$SHARED" ]]; then
        log "Shared: $SHARED ($(du -sh "$SHARED" | awk '{print $1}'))"
        log "Servers:"; ls -1t "$SHARED/cli/servers/" 2>/dev/null | sed 's/^/  /'
        log "Extensions ($(ls -1d "$SHARED"/extensions/*/ 2>/dev/null | wc -l)):"
        ls -1 "$SHARED/extensions/" 2>/dev/null | grep -v extensions.json | sed 's/^/  /'
    else
        warn "Not set up yet"
    fi
    echo ""
    log "Vhosts (all symlinked to $SHARED):"
    printf "  %-35s %-10s\n" "DOMAIN" "STATUS"
    for d in "$VHOSTS"/*/; do
        local dom; dom=$(basename "$d")
        [[ "$dom" =~ ^(system|chroot|default)$ ]] && continue
        local owner; owner=$(stat -c '%U' "$d" 2>/dev/null) || continue
        [[ "$owner" == "root" ]] && continue
        local vs="$d.vscode-server" st="missing"
        if [[ -L "$vs" && "$(readlink "$vs")" == "$SHARED" ]]; then
            st="symlinked"
        elif [[ -d "$vs" ]]; then
            st="standalone"
        fi
        printf "  %-35s %-10s\n" "$dom" "$st"
    done
}

cmd_cleanup() {
    need_root
    [[ -d "$SHARED/cli/servers" ]] || error "Run 'setup' first"
    local -a srvs; mapfile -t srvs < <(ls -1dt "$SHARED"/cli/servers/Stable-* 2>/dev/null)
    local n=${#srvs[@]} rm=0
    (( n <= KEEP )) && { log "Only $n version(s), nothing to remove"; return 0; }

    for (( i=KEEP; i<n; i++ )); do
        local c h; c=$(basename "${srvs[$i]}"); h="${c#Stable-}"
        log "  Removing: $c"
        rm -rf "${srvs[$i]}" "$SHARED/code-$h"
        find "$VHOSTS" -maxdepth 2 -name ".vscode-server" -type d 2>/dev/null | while IFS= read -r d; do
            rm -f "$d/code-$h" 2>/dev/null; rm -rf "$d/cli/servers/$c" 2>/dev/null
        done; rm=$((rm + 1))
    done
    for b in "$SHARED"/code-*; do
        [[ -f "$b" ]] || continue
        local h; h=$(basename "$b"); h="${h#code-}"
        [[ -d "$SHARED/cli/servers/Stable-$h" ]] || { rm -f "$b"; rm=$((rm + 1)); }
    done
    fix_perms; log "Removed $rm component(s) ($(du -sh "$SHARED" | awk '{print $1}'))"
}

cmd_cleanup_ext() {
    need_root
    [[ -d "$SHARED/extensions" ]] || error "Run 'setup' first"
    python3 -c "
import os,re,json,shutil
d='$SHARED/extensions'
groups={}
for e in sorted(os.listdir(d)):
    p=os.path.join(d,e)
    if not os.path.isdir(p): continue
    m=re.match(r'^(.+?)-(\d+\..+)$',e)
    if m: groups.setdefault(m[1],[]).append((e,p))
rm=0
for _,vs in groups.items():
    if len(vs)<=1: continue
    vs.sort(key=lambda x:os.path.getmtime(x[1]),reverse=True)
    for name,path in vs[1:]: print(f'  Removing: {name}'); shutil.rmtree(path); rm+=1
jf=os.path.join(d,'extensions.json')
if os.path.exists(jf):
    with open(jf) as f: exts=json.load(f)
    exts=[e for e in exts if os.path.isdir(os.path.join(d,e.get('relativeLocation','')))]
    for e in exts:
        r=e.get('relativeLocation','')
        if r: e['location']={'\$mid':1,'path':os.path.join(d,r),'scheme':'file'}
    with open(jf,'w') as f: json.dump(exts,f)
print(f'Removed {rm} old version(s)')
" 2>&1
    fix_perms; log "Extensions now: $(ls -1d "$SHARED"/extensions/*/ 2>/dev/null | wc -l)"
}

case "${1:-}" in
    update)      cmd_update ;;
    install-ext) cmd_install_ext "${2:-}" ;;
    update-ext)  cmd_update_ext ;;
    status)      cmd_status ;;
    cleanup)     cmd_cleanup ;;
    cleanup-ext) cmd_cleanup_ext ;;
    *)  cat <<'EOF'
Usage: ops-vscode-server.sh <command> [args]

  update             Download latest server + update extensions
  update-ext         Update extensions only
  install-ext <id>   Install extension to shared dir
  status             Show shared vs per-vhost usage
  cleanup            Remove old server versions (keep 2)
  cleanup-ext        Remove old extension versions

Initial setup and vhost symlinks are handled by plesk-init.sh.
EOF
        exit 1 ;;
esac
