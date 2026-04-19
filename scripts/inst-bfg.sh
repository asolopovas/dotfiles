#!/bin/bash
set -euo pipefail
source "$HOME/dotfiles/globals.sh"

DEST="$HOME/.local/bin/bfg.jar"
META="https://repo1.maven.org/maven2/com/madgag/bfg/maven-metadata.xml"

if [ "${FORCE:-false}" != true ] && [ -f "$DEST" ]; then
    print_color green "bfg already installed at $DEST — skipping"
    exit 0
fi

VERSION="$(curl -fsSL "$META" | grep -m1 '<release>' | sed -E 's@.*<release>(.*)</release>.*@\1@')"
[ -n "$VERSION" ] || { print_color red "Failed to resolve BFG latest version"; exit 1; }

print_color green "Installing BFG ${VERSION}..."
mkdir -p "$(dirname "$DEST")"
curl -fsSL "https://repo1.maven.org/maven2/com/madgag/bfg/${VERSION}/bfg-${VERSION}.jar" -o "$DEST"
print_color green "Installed to $DEST. Use: java -jar $DEST"
