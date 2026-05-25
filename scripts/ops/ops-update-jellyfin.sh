#!/usr/bin/env bash
set -euo pipefail

host=${1:-admin@192.168.1.100}
port=${2:-990}
ssh -p "$port" "$host" 'sh -s' <<'EOF'
set -eu
d=/share/CACHEDEV1_DATA/.qpkg/container-station/bin/docker
a=/share/CACHEDEV1_DATA/.qpkg/container-station/data/application/jellyfin
s=jellyfin
cd "$a"
"$d" compose -f docker-compose.yml -f docker-compose.resource.yml pull "$s"
"$d" compose -f docker-compose.yml -f docker-compose.resource.yml up -d "$s"
i=0
while [ "$i" -lt 24 ]; do
    h=$("$d" inspect "$s" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' 2>/dev/null || true)
    if [ "$h" = healthy ] || [ "$h" = running ]; then
        break
    fi
    i=$((i + 1))
    sleep 5
done
[ "$h" = healthy ] || [ "$h" = running ] || { "$d" logs --tail 80 "$s"; exit 1; }
"$d" inspect "$s" --format 'jellyfin {{index .Config.Labels "org.opencontainers.image.version"}} {{.Image}} {{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}'
EOF
