#!/bin/bash

# System
export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export EDITOR="vim"
export DOTFILES="$HOME/dotfiles"
export SUDO_ASKPASS="$HOME/dotfiles/helpers/tools/dmenupass"
export ANDROID_SDK_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/android"
export SSH_AUTH_SOCK="$GNOME_KEYRING_CONTROL/ssh"

# Oh My Bash
export OSH="$HOME/.local/share/ohmybash"

# Applications
export FILEMANAGER="pcmanfm"
export TERMINAL="alacrity"

# GoLang
export GOPATH="$HOME/go"
export GOBIN="$HOME/go/bin"
export GO111MODULE=on

# Docker Settings
export DOCKER_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/docker"
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

# NMP
export NPM_CONFIG_USERCONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/npm/npmrc"

export DOTFILES="$HOME/dotfiles"

env_vars=(
    env-vars
    include-paths
)

source_script() {
    local script_name=$1
    local script_path="$DOTFILES/env/$script_name.sh"
    [[ -f $script_path ]] && source $script_path || echo "Failed to source $script_path"
}
