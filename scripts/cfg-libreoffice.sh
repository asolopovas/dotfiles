#!/bin/bash
# Set LibreOffice icon theme to Breeze (Dark) for dark desktop themes
# Only runs on local desktop (skips WSL and SSH sessions)

# Skip in WSL
if grep -qi microsoft /proc/version 2>/dev/null || [ -n "${WSL_DISTRO_NAME:-}" ]; then
    return 0 2>/dev/null || exit 0
fi

# Skip in SSH sessions
if [ -n "${SSH_CLIENT:-}" ] || [ -n "${SSH_TTY:-}" ] || [ -n "${SSH_CONNECTION:-}" ]; then
    return 0 2>/dev/null || exit 0
fi

XCU="$HOME/.config/libreoffice/4/user/registrymodifications.xcu"

if [ ! -f "$XCU" ]; then
    echo "LibreOffice config not found at $XCU — skipping"
    return 0 2>/dev/null || exit 0
fi

if grep -q 'oor:name="SymbolStyle"' "$XCU"; then
    sed -i 's|<item oor:path="/org.openoffice.Office.Common/Misc"><prop oor:name="SymbolStyle"[^<]*<value>[^<]*</value></prop></item>|<item oor:path="/org.openoffice.Office.Common/Misc"><prop oor:name="SymbolStyle" oor:op="fuse"><value>breeze_dark</value></prop></item>|' "$XCU"
    echo "LibreOffice icon theme updated to breeze_dark"
else
    sed -i '/<\/oor:items>/i <item oor:path="/org.openoffice.Office.Common/Misc"><prop oor:name="SymbolStyle" oor:op="fuse"><value>breeze_dark</value></prop></item>' "$XCU"
    echo "LibreOffice icon theme set to breeze_dark"
fi
