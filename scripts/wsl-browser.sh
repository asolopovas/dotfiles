#!/bin/bash

# Install WSL browser opener for use with xdg-open
# This script creates a browser wrapper that opens URLs in Windows browser from WSL

set -e

BROWSER_SCRIPT="$HOME/.local/bin/browser-open"

# Create .local/bin directory if it doesn't exist
mkdir -p "$HOME/.local/bin"

# Create browser wrapper script
cat > "$BROWSER_SCRIPT" << 'EOF'
#!/bin/bash
cd /mnt/c && /mnt/c/Windows/System32/cmd.exe /c start "$1"
EOF

# Make it executable
chmod +x "$BROWSER_SCRIPT"

# Add to .env-vars if it exists
if [ -f "$HOME/.env-vars" ]; then
    # Remove existing BROWSER line if present
    sed -i '/^BROWSER=/d' "$HOME/.env-vars"
    # Add new BROWSER setting
    echo "BROWSER='$BROWSER_SCRIPT'" >> "$HOME/.env-vars"
    echo "Added BROWSER setting to ~/.env-vars"
else
    echo "BROWSER='$BROWSER_SCRIPT'" > "$HOME/.env-vars"
    echo "Created ~/.env-vars with BROWSER setting"
fi

echo "WSL browser opener installed successfully!"
echo "Restart your shell or run 'source ~/.env-vars' to use it."
echo "Test with: xdg-open https://google.com"