#!/bin/bash
set -euo pipefail
# shellcheck source=/home/andrius/dotfiles/globals.sh
source "$HOME/dotfiles/globals.sh"

FORCE=${1:-${FORCE:-false}}
LOCAL_BIN="$HOME/.local/bin"
PYTHON_SHIM="$LOCAL_BIN/python"

install_python_packages() {
    if [ "$FORCE" != true ] && cmd_exist python3 && cmd_exist pipx; then
        return 0
    fi

    case "$OS" in
        ubuntu | debian | linuxmint)
            installPackages python3 python3-pip python3-venv python-is-python3 pipx
            ;;
        arch)
            installPackages python python-pip python-pipx
            ;;
        centos)
            installPackages python3 python3-pip
            ;;
        fedora)
            pkg_install python3 python3-pip pipx
            ;;
        macos)
            if ! cmd_exist brew; then
                print_color red "Homebrew is required to install djlint dependencies on macOS"
                return 1
            fi
            cmd_exist python3 || brew install python
            cmd_exist pipx || brew install pipx
            ;;
        *)
            print_color red "Unsupported OS for djlint dependencies: $OS"
            return 1
            ;;
    esac
}

ensure_pipx() {
    if cmd_exist pipx; then
        return 0
    fi

    if ! cmd_exist python3; then
        print_color red "python3 is required to install pipx"
        return 1
    fi

    mkdir -p "$LOCAL_BIN"
    if ! python3 -m pip install --user pipx; then
        python3 -m pip install --user --break-system-packages pipx
    fi
    export PATH="$LOCAL_BIN:$PATH"
}

install_djlint() {
    if [ "$FORCE" != true ] && cmd_exist djlint; then
        print_color green "djlint already installed — skipping"
        return 0
    fi

    ensure_pipx
    pipx install --force djlint
    export PATH="$LOCAL_BIN:$PATH"
}

install_python_shim() {
    local python_target
    python_target="$(command -v python3 || true)"

    if [ -z "$python_target" ]; then
        print_color red "python3 was not found after dependency installation"
        return 1
    fi

    mkdir -p "$LOCAL_BIN"
    cat >"$PYTHON_SHIM" <<EOF
#!/bin/bash
if [ "\${1:-}" = "-m" ] && [ "\${2:-}" = "djlint" ] && command -v djlint >/dev/null 2>&1; then
    shift 2
    exec djlint "\$@"
fi
exec "$python_target" "\$@"
EOF
    chmod +x "$PYTHON_SHIM"
    export PATH="$LOCAL_BIN:$PATH"
}

install_python_packages
export PATH="$LOCAL_BIN:$PATH"
install_djlint

if [ "$FORCE" = true ] || ! cmd_exist python || ! python -m djlint --version >/dev/null 2>&1; then
    install_python_shim
    hash -r
fi

if ! cmd_exist python; then
    print_color red "python command is still unavailable"
    exit 1
fi

if ! python -m djlint --version >/dev/null 2>&1; then
    print_color red "python -m djlint is still unavailable"
    exit 1
fi

print_color green "djlint dependencies ready: python=$(command -v python) djlint=$(command -v djlint)"
