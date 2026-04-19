#!/bin/bash
set -euo pipefail

DEST="$HOME/.local/bin/bfg.jar"
META="https://repo1.maven.org/maven2/com/madgag/bfg/maven-metadata.xml"

VERSION="$(curl -fsSL "$META" | grep -m1 '<release>' | sed -E 's@.*<release>(.*)</release>.*@\1@')"
[ -n "$VERSION" ] || { echo "Failed to resolve BFG latest version" >&2; exit 1; }

echo "Installing BFG ${VERSION}..."
mkdir -p "$(dirname "$DEST")"
curl -fsSL "https://repo1.maven.org/maven2/com/madgag/bfg/${VERSION}/bfg-${VERSION}.jar" -o "$DEST"
echo "Installed to $DEST. Use: java -jar $DEST"
