#!/usr/bin/env bash

CONFIG_DIR=$HOME/dotfiles/config/polybar
THEME=${1:-minimal}
TEMPLATE_DIR=$CONFIG_DIR/themes/$THEME
OUTPUT_DIR=/tmp/polybar-$THEME

# Create output directory
mkdir -p $OUTPUT_DIR

# Substitute environment variables in config files
envsubst < $TEMPLATE_DIR/config.ini > $OUTPUT_DIR/config.ini
envsubst < $CONFIG_DIR/fonts.ini > $OUTPUT_DIR/fonts.ini

# Copy other files as-is
cp -r $TEMPLATE_DIR/* $OUTPUT_DIR/
cp $CONFIG_DIR/modules.ini $OUTPUT_DIR/

# Update paths in config to point to generated files
sed -i "s|\$CONFIG_DIR/fonts.ini|$OUTPUT_DIR/fonts.ini|g" $OUTPUT_DIR/config.ini
sed -i "s|\$CONFIG_DIR/modules.ini|$OUTPUT_DIR/modules.ini|g" $OUTPUT_DIR/config.ini

echo $OUTPUT_DIR/config.ini