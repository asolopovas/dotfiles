#!/bin/bash
set -euo pipefail
source "$HOME/dotfiles/globals.sh"

JAR="$HOME/.local/share/bfg/bfg.jar"
BIN="$HOME/.local/bin/bfg"
META="https://repo1.maven.org/maven2/com/madgag/bfg/maven-metadata.xml"

if [ "${FORCE:-false}" != true ] && cmd_exist bfg; then
    print_color green "bfg already installed at $(command -v bfg) — skipping"
    exit 0
fi

if ! cmd_exist java; then
    print_color red "java is required to run bfg (install a JRE)"
    exit 1
fi

VERSION="$(curl -fsSL "$META" | grep -m1 '<release>' | sed -E 's@.*<release>(.*)</release>.*@\1@')"
[ -n "$VERSION" ] || { print_color red "Failed to resolve BFG latest version"; exit 1; }

print_color green "Installing BFG ${VERSION}..."
mkdir -p "$(dirname "$JAR")" "$(dirname "$BIN")"
curl -fsSL "https://repo1.maven.org/maven2/com/madgag/bfg/${VERSION}/bfg-${VERSION}.jar" -o "$JAR"

cat >"$BIN" <<EOF
#!/bin/bash
exec java -jar "$JAR" "\$@"
EOF
chmod +x "$BIN"

print_color green "Installed bfg ${VERSION} -> $BIN"
