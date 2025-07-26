#!/bin/bash

# Install fastcompmgr - a fast compositor for X
# https://github.com/tycho-kirchner/fastcompmgr

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Installing fastcompmgr...${NC}"

# Create ~/src directory if it doesn't exist
mkdir -p ~/src

# Remove existing installation if present
if command -v fastcompmgr &> /dev/null; then
    echo -e "${YELLOW}Removing existing fastcompmgr installation...${NC}"
    sudo make -C ~/src/fastcompmgr uninstall 2>/dev/null || true
fi

# Install build dependencies
echo -e "${YELLOW}Installing build dependencies...${NC}"
sudo apt update
sudo apt install -y libx11-dev libxcomposite-dev libxdamage-dev libxfixes-dev libxrender-dev pkg-config make build-essential git

# Clone or update repository
if [ -d ~/src/fastcompmgr ]; then
    echo -e "${YELLOW}Updating existing repository...${NC}"
    cd ~/src/fastcompmgr
    git pull
    make clean
else
    echo -e "${YELLOW}Cloning fastcompmgr repository...${NC}"
    cd ~/src
    git clone https://github.com/tycho-kirchner/fastcompmgr.git
    cd fastcompmgr
fi

# Build and install
echo -e "${YELLOW}Building fastcompmgr...${NC}"
make

echo -e "${YELLOW}Installing fastcompmgr...${NC}"
sudo make install

# Verify installation
if command -v fastcompmgr &> /dev/null; then
    echo -e "${GREEN}fastcompmgr installed successfully!${NC}"
    echo -e "${GREEN}Version:${NC} $(fastcompmgr --help | head -1)"
    echo -e "${GREEN}Location:${NC} $(which fastcompmgr)"
else
    echo -e "${RED}Installation failed!${NC}"
    exit 1
fi

echo -e "${GREEN}Done! You can now use fastcompmgr in your compositor setup.${NC}"