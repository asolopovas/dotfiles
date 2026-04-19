#!/bin/bash
set -euo pipefail
source "$HOME/dotfiles/globals.sh"

FORCE=${1:-${FORCE:-false}}

install_shellcheck() {
    if [ "$FORCE" != true ] && cmd_exist shellcheck; then
        print_color green "shellcheck already installed"
        return 0
    fi
    case "$OS" in
        ubuntu | debian | linuxmint) installPackages shellcheck ;;
        arch) installPackages shellcheck ;;
        centos | fedora) sudo dnf install -y ShellCheck ;;
        macos) brew install shellcheck ;;
        *)
            print_color red "Unsupported OS for shellcheck: $OS"
            return 1
            ;;
    esac
}

install_shfmt() {
    if [ "$FORCE" != true ] && cmd_exist shfmt; then
        print_color green "shfmt already installed"
        return 0
    fi
    case "$OS" in
        macos)
            brew install shfmt
            return 0
            ;;
    esac

    local shfmt_arch
    case "$ARCH" in
        x86_64) shfmt_arch="amd64" ;;
        aarch64) shfmt_arch="arm64" ;;
        *) shfmt_arch="amd64" ;;
    esac

    local ver
    ver="$(gh_latest_release mvdan/sh --keep-v)"
    print_color green "Installing shfmt ${ver}..."
    mkdir -p "$HOME/.local/bin"
    curl -fsSL "https://github.com/mvdan/sh/releases/download/${ver}/shfmt_${ver}_linux_${shfmt_arch}" \
        -o "$HOME/.local/bin/shfmt"
    chmod +x "$HOME/.local/bin/shfmt"
}

install_shellcheck
install_shfmt

print_color green "Lint tools ready: $(command -v shellcheck) $(command -v shfmt)"
