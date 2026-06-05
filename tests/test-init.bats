#!/usr/bin/env bats

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    FAKE_HOME="$(mktemp -d)"
    export FAKE_HOME
    TMPDIR="$(mktemp -d)"
    export TMPDIR
    mkdir -p "$FAKE_HOME/dotfiles"
    cp "$REPO_DIR/globals.sh" "$FAKE_HOME/dotfiles/globals.sh"
    HOME="$FAKE_HOME" source "$FAKE_HOME/dotfiles/globals.sh"
}

teardown() {
    rm -rf "$FAKE_HOME" "$TMPDIR"
}

make_fake_cmd() {
    local dir="$TMPDIR/fakebin" name="$1" output="${2:-0.0.1}"
    mkdir -p "$dir"
    printf '#!/bin/sh\necho "%s"\n' "$output" >"$dir/$name"
    chmod +x "$dir/$name"
    printf '%s\n' "$dir"
}

setup_fake_dotfiles() {
    mkdir -p "$FAKE_HOME/dotfiles/scripts" "$FAKE_HOME/dotfiles/.config/fish" "$FAKE_HOME/dotfiles/.config/tmux" "$FAKE_HOME/dotfiles/.config/nvim" "$FAKE_HOME/dotfiles/.config/opencode" "$FAKE_HOME/dotfiles/helpers"
    touch "$FAKE_HOME/dotfiles/.bashrc" "$FAKE_HOME/dotfiles/.gitconfig" "$FAKE_HOME/dotfiles/.gitignore" "$FAKE_HOME/dotfiles/.Xresources" "$FAKE_HOME/dotfiles/.config/.func" "$FAKE_HOME/dotfiles/.config/.aliasrc" "$FAKE_HOME/dotfiles/.config/opencode/opencode.jsonc"
    cp "$REPO_DIR/globals.sh" "$FAKE_HOME/dotfiles/globals.sh"
    cp "$REPO_DIR/scripts/cfg-default-dirs.sh" "$FAKE_HOME/dotfiles/scripts/cfg-default-dirs.sh"
}

@test "init: detects supported os and arch" {
    eval "$(sed -n '/^_detect_os()/,/^}/p' "$REPO_DIR/init.sh")"
    eval "$(sed -n '/^_detect_arch()/,/^}/p' "$REPO_DIR/init.sh")"
    [[ "$(_detect_os)" =~ ^(ubuntu|debian|linuxmint|fedora|centos|arch|macos|linux|unknown)$ ]]
    case "$(uname -m)" in
        x86_64 | amd64) [ "$(_detect_arch)" = "x86_64" ] ;;
        aarch64 | arm64) [ "$(_detect_arch)" = "aarch64" ] ;;
        *) [ "$(_detect_arch)" = "$(uname -m)" ] ;;
    esac
}

@test "init: removes broken symlinks safely" {
    mkdir -p "$TMPDIR/d/sub"
    printf 'data\n' >"$TMPDIR/d/file"
    ln -s /missing-one "$TMPDIR/d/broken"
    ln -s "$TMPDIR/d/file" "$TMPDIR/d/good"
    ln -s /nested-missing "$TMPDIR/d/sub/nested"
    fix_broken_symlinks "$TMPDIR/d"
    [ ! -L "$TMPDIR/d/broken" ]
    [ -L "$TMPDIR/d/good" ]
    [ -L "$TMPDIR/d/sub/nested" ]
    fix_broken_symlinks "$TMPDIR/d" --recursive
    [ ! -L "$TMPDIR/d/sub/nested" ]
    run fix_broken_symlinks "$TMPDIR/nope"
    [ "$status" -eq 0 ]
}

@test "init: installers skip existing tools" {
    local bin
    bin="$(make_fake_cmd bun 1.1.0)"
    make_fake_cmd deno "deno 1.40.0" >/dev/null
    make_fake_cmd fd "fd 10.3.0" >/dev/null
    make_fake_cmd fish "fish 3.7.0" >/dev/null
    make_fake_cmd cargo "cargo 1.80.0" >/dev/null
    for installer in inst-bun.sh inst-deno.sh inst-fd.sh inst-fish.sh inst-cargo.sh; do
        run env HOME="$FAKE_HOME" PATH="$bin:$PATH" FORCE=false bash "$REPO_DIR/scripts/inst/$installer"
        [[ "$output" == *"already installed"* ]]
    done
}

@test "init: FORCE bypasses installer skip" {
    local bin
    bin="$(make_fake_cmd bun 1.1.0)"
    printf '#!/bin/sh\nexit 0\n' >"$bin/curl"
    chmod +x "$bin/curl"
    run env HOME="$FAKE_HOME" PATH="$bin:$PATH" FORCE=true bash "$REPO_DIR/scripts/inst/inst-bun.sh"
    [[ "$output" == *"Installing bun"* ]]
    [[ "$output" != *"already installed"* ]]
}

@test "init: fzf skips local or PATH binary" {
    mkdir -p "$FAKE_HOME/.local/bin"
    touch "$FAKE_HOME/.local/bin/fzf"
    run env HOME="$FAKE_HOME" FORCE=false bash "$REPO_DIR/scripts/inst/inst-fzf.sh"
    [[ "$output" != *"Installing fzf"* ]]
    rm -f "$FAKE_HOME/.local/bin/fzf"
    local bin
    bin="$(make_fake_cmd fzf 0.42.0)"
    run env HOME="$FAKE_HOME" PATH="$bin:$PATH" FORCE=false bash "$REPO_DIR/scripts/inst/inst-fzf.sh"
    [[ "$output" != *"Installing fzf"* ]]
}

@test "init: cfg-default-dirs keeps valid links and tolerates missing sources" {
    setup_fake_dotfiles
    mkdir -p "$FAKE_HOME/.config"
    ln -s /nonexistent "$FAKE_HOME/.config/broken-app"
    touch "$FAKE_HOME/.config/real-file"
    ln -s "$FAKE_HOME/.config/real-file" "$FAKE_HOME/.config/valid-link"
    run env HOME="$FAKE_HOME" DOTFILES_DIR="$FAKE_HOME/dotfiles" NVIM=true SYSTEM=false ZSH=false bash "$FAKE_HOME/dotfiles/scripts/cfg-default-dirs.sh"
    [ "$status" -eq 0 ]
    [ ! -L "$FAKE_HOME/.config/broken-app" ]
    [ -L "$FAKE_HOME/.config/valid-link" ]
    rm -rf "$FAKE_HOME/dotfiles/.config/fish"
    run env HOME="$FAKE_HOME" DOTFILES_DIR="$FAKE_HOME/dotfiles" NVIM=false SYSTEM=false ZSH=false bash "$FAKE_HOME/dotfiles/scripts/cfg-default-dirs.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Source missing"* ]]
}

@test "init: nvim config symlink is idempotent" {
    mkdir -p "$FAKE_HOME/.config" "$FAKE_HOME/dotfiles/.config/nvim"
    run bash -c "
        HOME='$FAKE_HOME' DOTFILES_DIR='$FAKE_HOME/dotfiles'
        eval \"\$(sed -n '/^ensure_nvim_config()/,/^}/p' '$REPO_DIR/scripts/inst/inst-nvim.sh')\"
        ensure_nvim_config
        ensure_nvim_config
        readlink '$FAKE_HOME/.config/nvim'
    "
    [[ "$output" == *"$FAKE_HOME/dotfiles/.config/nvim"* ]]
}
