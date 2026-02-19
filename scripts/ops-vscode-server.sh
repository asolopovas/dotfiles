#!/bin/bash
set -euo pipefail

SHARED="/opt/vscode-server"
VHOSTS="/var/www/vhosts"
GROUP="psacln"
KEEP=2

log()   { printf '\033[32m[vscode-server]\033[0m %s\n' "$*"; }
warn()  { printf '\033[33m[vscode-server]\033[0m %s\n' "$*" >&2; }
error() { printf '\033[31m[vscode-server]\033[0m %s\n' "$*" >&2; exit 1; }
need_root() { [[ $EUID -eq 0 ]] || error "Must run as root"; }

all_vhosts() {
    for d in "$VHOSTS"/*/; do
        local n; n=$(basename "$d")
        [[ "$n" =~ ^(system|chroot|default)$ ]] && continue
        local o; o=$(stat -c '%U' "$d" 2>/dev/null) || continue
        [[ "$o" != "root" ]] && echo "$d"
    done
}

fix_perms() {
    chown -R root:"$GROUP" "$SHARED"
    find "$SHARED" -type d -exec chmod 750 {} +
    find "$SHARED" -type f -exec chmod 640 {} +
    find "$SHARED" -type f \( -name "code-*" -o -name "node" -o -name "*.sh" \
        -o -path "*/bin/*" -o -path "*/.bin/*" \) -exec chmod 750 {} +
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

merge_ext_json() {
    local src="$1" dst="$SHARED/extensions/extensions.json"
    [[ -f "$src" ]] || return 0
    [[ -f "$dst" ]] || { cp "$src" "$dst"; return 0; }
    python3 -c "
import json
with open('$dst') as f: t=json.load(f)
with open('$src') as f: s=json.load(f)
idx={e.get('relativeLocation',''):e for e in t}
for e in s:
    r=e.get('relativeLocation','')
    if r and r not in idx: idx[r]=e
with open('$dst','w') as f: json.dump(list(idx.values()),f)
" 2>/dev/null || warn "python3 failed merging extensions.json"
}

migrate_one() {
    local home="$1" domain owner vs
    domain=$(basename "$home")
    owner=$(stat -c '%U' "$home")
    vs="$home/.vscode-server"
    mkdir -p "$vs"

    [[ -L "$vs/cli/servers" ]] && rm -f "$vs/cli/servers"
    if [[ -d "$vs/cli/servers" ]]; then
        for s in "$vs"/cli/servers/Stable-*/; do
            [[ -d "$s" && ! -L "$s/server" ]] && rm -rf "$s"
        done
    fi
    mkdir -p "$vs/cli/servers"
    for s in "$SHARED"/cli/servers/Stable-*/; do
        [[ -d "$s" ]] || continue
        local v="$vs/cli/servers/$(basename "$s")"
        mkdir -p "$v"
        ln -sfn "$s/server" "$v/server"
        chown "$owner:$GROUP" "$v"
    done
    [[ -f "$SHARED/cli/servers/lru.json" ]] && \
        cp -f "$SHARED/cli/servers/lru.json" "$vs/cli/servers/lru.json" 2>/dev/null || true

    for b in "$vs"/code-*; do [[ -e "$b" || -L "$b" ]] && rm -f "$b"; done
    for b in "$SHARED"/code-*; do
        [[ -f "$b" ]] && ln -sfn "$b" "$vs/$(basename "$b")"
    done

    [[ -d "$vs/extensions" && ! -L "$vs/extensions" ]] && rm -rf "$vs/extensions"
    ln -sfn "$SHARED/extensions" "$vs/extensions"

    find "$vs" -maxdepth 1 -name ".cli.*.log" -delete 2>/dev/null || true
    chown -h "$owner:$GROUP" "$vs" "$vs/cli" "$vs/cli/servers" 2>/dev/null || true
    chown -h "$owner:$GROUP" "$vs"/code-* "$vs/extensions" 2>/dev/null || true
    [[ -d "$vs/data" ]] && chown -R "$owner:$GROUP" "$vs/data"
    chown "$owner:$GROUP" "$vs/cli/servers/lru.json" 2>/dev/null || true

    log "[$domain] done"
}

cmd_setup() {
    need_root
    [[ -d "$SHARED/cli/servers" ]] && error "Already exists at $SHARED — remove first or use 'update'"

    local seed="" best=0
    while IFS= read -r d; do
        local sz; sz=$(du -sb "$d" 2>/dev/null | awk '{print $1}')
        (( sz > best )) && { seed="$d"; best=$sz; }
    done < <(find "$VHOSTS" -maxdepth 2 -name ".vscode-server" -type d 2>/dev/null)
    [[ -n "$seed" ]] || error "No .vscode-server found in any vhost"

    log "Seeding from: $seed"
    mkdir -p "$SHARED"/{cli,extensions}
    [[ -d "$seed/cli/servers" ]] && cp -a "$seed/cli/servers" "$SHARED/cli/"
    for b in "$seed"/code-*; do [[ -f "$b" ]] && cp -a "$b" "$SHARED/"; done
    [[ -d "$seed/extensions" ]] && rsync -a "$seed/extensions/" "$SHARED/extensions/"

    while IFS= read -r d; do
        [[ "$d" == "$seed" ]] && continue
        for s in "$d"/cli/servers/Stable-*; do
            [[ -d "$s" && ! -d "$SHARED/cli/servers/$(basename "$s")" ]] && cp -a "$s" "$SHARED/cli/servers/"
        done
        for b in "$d"/code-*; do
            [[ -f "$b" && ! -f "$SHARED/$(basename "$b")" ]] && cp -a "$b" "$SHARED/"
        done
        for e in "$d"/extensions/*/; do
            [[ -d "$e" && ! -d "$SHARED/extensions/$(basename "$e")" ]] && cp -a "$e" "$SHARED/extensions/"
        done
        [[ -f "$d/extensions/extensions.json" ]] && merge_ext_json "$d/extensions/extensions.json"
    done < <(find "$VHOSTS" -maxdepth 2 -name ".vscode-server" -type d 2>/dev/null | sort)

    rebuild_ext_json
    fix_perms
    log "Ready at $SHARED ($(du -sh "$SHARED" | awk '{print $1}'))"
}

cmd_migrate() {
    need_root
    [[ -d "$SHARED/cli/servers" ]] || error "Run 'setup' first"
    if [[ -n "${1:-}" ]]; then
        [[ -d "$VHOSTS/$1" ]] || error "Vhost not found: $1"
        migrate_one "$VHOSTS/$1"
    else
        while IFS= read -r h; do migrate_one "$h"; done < <(all_vhosts)
    fi
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
        while IFS= read -r h; do migrate_one "$h"; done < <(all_vhosts)
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
    log "Vhosts:"
    printf "  %-35s %-10s %-10s\n" "DOMAIN" "STATUS" "DATA"
    find "$VHOSTS" -maxdepth 2 -name ".vscode-server" -type d 2>/dev/null | sort | while IFS= read -r d; do
        local dom st sz
        dom=$(basename "$(dirname "$d")")
        st="standalone"
        for s in "$d"/cli/servers/Stable-*/server; do [[ -L "$s" ]] && { st="migrated"; break; }; done
        sz=$([[ -d "$d/data" ]] && du -sh "$d/data" 2>/dev/null | awk '{print $1}' || echo "-")
        printf "  %-35s %-10s %-10s\n" "$dom" "$st" "$sz"
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
    setup)       cmd_setup ;;
    migrate)     cmd_migrate "${2:-}" ;;
    update)      cmd_update ;;
    install-ext) cmd_install_ext "${2:-}" ;;
    update-ext)  cmd_update_ext ;;
    status)      cmd_status ;;
    cleanup)     cmd_cleanup ;;
    cleanup-ext) cmd_cleanup_ext ;;
    provision)   need_root; [[ -d "$SHARED/cli/servers" ]] || error "Run 'setup' first"
                 [[ -n "${2:-}" ]] || error "Usage: $0 provision <domain>"
                 [[ -d "$VHOSTS/$2" ]] || error "Vhost not found: $2"
                 migrate_one "$VHOSTS/$2" ;;
    *)  cat <<'EOF'
Usage: ops-vscode-server.sh <command> [args]

  setup              Seed shared dir from existing vhosts
  migrate [domain]   Migrate one or all vhosts to shared server
  update             Download latest server + update extensions
  update-ext         Update extensions only
  install-ext <id>   Install extension to shared dir
  status             Show shared vs per-vhost usage
  cleanup            Remove old server versions (keep 2)
  cleanup-ext        Remove old extension versions
  provision <domain> Set up new vhost

Workflow: setup -> cleanup -> migrate -> status
Ongoing:  update | install-ext <id> | provision <dom> | cleanup
EOF
        exit 1 ;;
esac
