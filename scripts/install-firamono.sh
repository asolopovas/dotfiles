#!/bin/bash

# Create the custom fonts directory if it doesn't already exist
sudo mkdir -p /usr/share/fonts/custom

# Download the FiraMono.zip file from the specified URL
wget -P /tmp https://github.com/ryanoasis/nerd-fonts/releases/download/v2.3.3/FiraMono.zip

# Unzip the contents of FiraMono.zip into the custom fonts directory
sudo unzip /tmp/FiraMono.zip -d /usr/share/fonts/custom/FiraMono

# Remove the zip file from the /tmp directory
rm /tmp/FiraMono.zip

# Update the font cache
sudo fc-cache -fv
