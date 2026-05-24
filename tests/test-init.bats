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
    local dir="$TMPDIR/fakebin" name=$1 output=${2:-"0.0.1"}
    mkdir -p "$dir"
    printf '#!/bin/sh\necho "%s"\n' "$output" >"$dir/$name"
    chmod +x "$dir/$name"
    echo "$dir"
}

setup_fake_dotfiles() {
    mkdir -p "$FAKE_HOME/dotfiles/scripts" "$FAKE_HOME/dotfiles/.config/fish" "$FAKE_HOME/dotfiles/.config/tmux" "$FAKE_HOME/dotfiles/.config/nvim" "$FAKE_HOME/dotfiles/.config/opencode" "$FAKE_HOME/dotfiles/helpers"
    touch "$FAKE_HOME/dotfiles/.bashrc" "$FAKE_HOME/dotfiles/.gitconfig" "$FAKE_HOME/dotfiles/.gitignore" "$FAKE_HOME/dotfiles/.Xresources" "$FAKE_HOME/dotfiles/.config/.func" "$FAKE_HOME/dotfiles/.config/.aliasrc" "$FAKE_HOME/dotfiles/.config/opencode/opencode.jsonc"
    cp "$REPO_DIR/globals.sh" "$FAKE_HOME/dotfiles/globals.sh"
    cp "$REPO_DIR/scripts/cfg-default-dirs.sh" "$FAKE_HOME/dotfiles/scripts/cfg-default-dirs.sh"
}

@test "init detection functions return expected values" {
    eval "$(sed -n '/^_detect_os()/,/^}/p' "$REPO_DIR/init.sh")"
    eval "$(sed -n '/^_detect_arch()/,/^}/p' "$REPO_DIR/init.sh")"
    [[ "$(_detect_os)" =~ ^(ubuntu|debian|linuxmint|fedora|centos|arch|macos|linux|unknown)$ ]]
    local raw arch
    raw="$(uname -m)"
    arch="$(_detect_arch)"
    case "$raw" in
        x86_64 | amd64) [[ "$arch" == "x86_64" ]] ;;
        aarch64 | arm64) [[ "$arch" == "aarch64" ]] ;;
        *) [[ "$arch" == "$raw" ]] ;;
    esac
}

@test "fix_broken_symlinks: cleans top-level broken links safely" {
    mkdir -p "$TMPDIR/d/sub"
    echo data >"$TMPDIR/d/file"
    ln -s /missing-one "$TMPDIR/d/broken"
    ln -s "$TMPDIR/d/file" "$TMPDIR/d/good"
    ln -s /nested-missing "$TMPDIR/d/sub/nested"
    fix_broken_symlinks "$TMPDIR/d"
    [[ ! -L "$TMPDIR/d/broken" ]]
    [[ -L "$TMPDIR/d/good" ]]
    [[ -L "$TMPDIR/d/sub/nested" ]]
    [[ "$(cat "$TMPDIR/d/file")" == "data" ]]
    run fix_broken_symlinks "$TMPDIR/nope"
    [[ "$status" -eq 0 ]]
}

@test "fix_broken_symlinks: recursive mode cleans nested broken links" {
    mkdir -p "$TMPDIR/d/sub"
    ln -s /nested-missing "$TMPDIR/d/sub/nested"
    fix_broken_symlinks "$TMPDIR/d" --recursive
    [[ ! -L "$TMPDIR/d/sub/nested" ]]
}

@test "pkg_install: function exists" {
    declare -f pkg_install >/dev/null
}

@test "installers: skip when tools already exist" {
    local bin
    bin=$(make_fake_cmd bun "1.1.0")
    make_fake_cmd deno "deno 1.40.0" >/dev/null
    make_fake_cmd fd "fd 10.3.0" >/dev/null
    make_fake_cmd fish "fish 3.7.0" >/dev/null
    make_fake_cmd cargo "cargo 1.80.0" >/dev/null
    run env HOME="$FAKE_HOME" PATH="$bin:$PATH" FORCE=false bash "$REPO_DIR/scripts/inst/inst-bun.sh"
    [[ "$output" == *"already installed"* ]]
    run env HOME="$FAKE_HOME" PATH="$bin:$PATH" FORCE=false bash "$REPO_DIR/scripts/inst/inst-deno.sh"
    [[ "$output" == *"already installed"* ]]
    run env HOME="$FAKE_HOME" PATH="$bin:$PATH" FORCE=false bash "$REPO_DIR/scripts/inst/inst-fd.sh"
    [[ "$output" == *"already installed"* ]]
    run env HOME="$FAKE_HOME" PATH="$bin:$PATH" FORCE=false bash "$REPO_DIR/scripts/inst/inst-fish.sh"
    [[ "$output" == *"already installed"* ]]
    run env HOME="$FAKE_HOME" PATH="$bin:$PATH" FORCE=false bash "$REPO_DIR/scripts/inst/inst-cargo.sh"
    [[ "$output" == *"already installed"* ]]
}

@test "inst-bun.sh: FORCE bypasses installed check" {
    local bin
    bin=$(make_fake_cmd bun "1.1.0")
    printf '#!/bin/sh\nexit 0\n' >"$bin/curl"
    chmod +x "$bin/curl"
    run env HOME="$FAKE_HOME" PATH="$bin:$PATH" FORCE=true bash "$REPO_DIR/scripts/inst/inst-bun.sh"
    [[ "$output" == *"Installing bun"* ]]
    [[ "$output" != *"already installed"* ]]
}

@test "inst-fzf.sh: skips existing local or PATH binary" {
    mkdir -p "$FAKE_HOME/.local/bin"
    touch "$FAKE_HOME/.local/bin/fzf"
    run env HOME="$FAKE_HOME" FORCE=false bash "$REPO_DIR/scripts/inst/inst-fzf.sh"
    [[ "$output" != *"Installing fzf"* ]]
    rm -f "$FAKE_HOME/.local/bin/fzf"
    local bin
    bin=$(make_fake_cmd fzf "0.42.0")
    run env HOME="$FAKE_HOME" PATH="$bin:$PATH" FORCE=false bash "$REPO_DIR/scripts/inst/inst-fzf.sh"
    [[ "$output" != *"Installing fzf"* ]]
}

@test "cfg-default-dirs: cleans broken links and preserves valid links" {
    setup_fake_dotfiles
    mkdir -p "$FAKE_HOME/.config"
    ln -s /nonexistent "$FAKE_HOME/.config/broken-app"
    touch "$FAKE_HOME/.config/real-file"
    ln -s "$FAKE_HOME/.config/real-file" "$FAKE_HOME/.config/valid-link"
    env HOME="$FAKE_HOME" DOTFILES_DIR="$FAKE_HOME/dotfiles" NVIM=true SYSTEM=false ZSH=false bash "$FAKE_HOME/dotfiles/scripts/cfg-default-dirs.sh"
    [[ ! -L "$FAKE_HOME/.config/broken-app" ]]
    [[ -L "$FAKE_HOME/.config/valid-link" ]]
}

@test "cfg-default-dirs: skips missing source files" {
    mkdir -p "$FAKE_HOME/dotfiles/scripts" "$FAKE_HOME/dotfiles/.config" "$FAKE_HOME/dotfiles/helpers"
    cp "$REPO_DIR/globals.sh" "$FAKE_HOME/dotfiles/globals.sh"
    cp "$REPO_DIR/scripts/cfg-default-dirs.sh" "$FAKE_HOME/dotfiles/scripts/cfg-default-dirs.sh"
    run env HOME="$FAKE_HOME" DOTFILES_DIR="$FAKE_HOME/dotfiles" NVIM=false SYSTEM=false ZSH=false bash "$FAKE_HOME/dotfiles/scripts/cfg-default-dirs.sh"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Source missing"* ]]
}

@test "inst-nvim: ensure_nvim_config creates and keeps symlink" {
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
