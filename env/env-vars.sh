#!/bin/bash

export LANGUAGE=en_GB.UTF-8
export LANG=en_GB.UTF-8
export EDITOR="vim"
export DOTFILES="$HOME/dotfiles"
export SUDO_ASKPASS="$HOME/dotfiles/helpers/tools/dmenu-pass"
export ANDROID_SDK_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/android"
export SSH_AUTH_SOCK="$GNOME_KEYRING_CONTROL/ssh"

export OSH="$HOME/.local/share/ohmybash"

export FILEMANAGER="thunar"
export TERMINAL="alacrity"

export GOPATH="$HOME/go"
export GOBIN="$HOME/go/bin"
export GO111MODULE=on

export DOCKER_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/docker"
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

export NPM_CONFIG_USERCONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/npm/npmrc"
export DOTFILES_DIR="$HOME/dotfiles"

export PHPENV_SHELL=bash
