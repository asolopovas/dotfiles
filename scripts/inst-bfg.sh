#!/bin/bash

VERSION="1.15.0"
curl -fsSL https://repo1.maven.org/maven2/com/madgag/bfg/$VERSION/bfg-$VERSION.jar -o $HOME/.local/bin/bfg.jar
echo "Installation complete. You can now use the 'bfg' command."
