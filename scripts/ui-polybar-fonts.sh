#!/bin/bash
# Generate polybar font configuration from template using environment variables

# Source environment variables
[ -f "$HOME/.env-vars" ] && source "$HOME/.env-vars"

# Export variables for envsubst
export POLYBAR_FONT_SIZE POLYBAR_FONT_SIZE_LARGE

POLYBAR_CONFIG_DIR="$HOME/dotfiles/config/polybar"
TEMPLATE_FILE="$POLYBAR_CONFIG_DIR/fonts.ini.template"
OUTPUT_FILE="$POLYBAR_CONFIG_DIR/fonts.ini"

if [ -f "$TEMPLATE_FILE" ]; then
    # Generate fonts.ini from template with environment variables
    envsubst < "$TEMPLATE_FILE" > "$OUTPUT_FILE"
    echo "Generated polybar fonts config with size: $POLYBAR_FONT_SIZE"
else
    echo "Template file not found: $TEMPLATE_FILE"
    exit 1
fi