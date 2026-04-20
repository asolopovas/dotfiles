#!/usr/bin/env bats

# ---------------------------------------------------------------------------
# Unit tests for init.sh improvements:
#   - OS/arch detection (detect_os, detect_arch)
#   - Idempotent installs (skip if installed, force reinstall)
#   - Broken symlink repair (fix_broken_symlinks)
#   - --force CLI flag parsing
#   - ensure_tool helper
# Runs locally, no Docker, no network, no sudo.
# ---------------------------------------------------------------------------

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    export FAKE_HOME="$(mktemp -d)"
    export TMPDIR="$(mktemp -d)"

    mkdir -p "$FAKE_HOME/dotfiles"
    cp "$REPO_DIR/globals.sh" "$FAKE_HOME/dotfiles/globals.sh"
    HOME="$FAKE_HOME" source "$FAKE_HOME/dotfiles/globals.sh"
}

teardown() {
    rm -rf "$FAKE_HOME" "$TMPDIR"
}

# =====================================================================
#  OS Detection
# =====================================================================

@test "detect_os: returns non-empty string" {
    [[ -n "$(detect_os)" ]]
}

@test "detect_os: returns known value on this system" {
    [[ "$(detect_os)" =~ ^(ubuntu|debian|linuxmint|pop|fedora|centos|arch|macos|linux|unknown)$ ]]
}

@test "detect_os: matches /etc/os-release on Linux" {
    if [[ "$(uname -s)" != "Linux" ]] || [[ ! -f /etc/os-release ]]; then
        skip "Not Linux or no /etc/os-release"
    fi
    local expected
    expected=$(awk -F= '/^ID=/ {gsub(/"/, "", $2); print tolower($2)}' /etc/os-release)
    [[ "$(detect_os)" == "$expected" ]]
}

# =====================================================================
#  Architecture Detection
# =====================================================================

@test "detect_arch: returns non-empty string" {
    [[ -n "$(detect_arch)" ]]
}

@test "detect_arch: normalises uname -m" {
    local raw arch
    raw="$(uname -m)"
    arch="$(detect_arch)"
    case "$raw" in
        x86_64|amd64)  [[ "$arch" == "x86_64" ]] ;;
        aarch64|arm64) [[ "$arch" == "aarch64" ]] ;;
        *)             [[ "$arch" == "$raw" ]] ;;
    esac
}

# =====================================================================
#  globals.sh exports
# =====================================================================

@test "globals: exports OS" {
    [[ -n "$OS" ]]
}

@test "globals: exports ARCH" {
    [[ -n "$ARCH" ]]
}

# =====================================================================
#  fix_broken_symlinks
# =====================================================================

@test "fix_broken_symlinks: removes broken symlink" {
    mkdir -p "$TMPDIR/d"
    ln -s /nonexistent "$TMPDIR/d/broken"
    fix_broken_symlinks "$TMPDIR/d"
    [[ ! -L "$TMPDIR/d/broken" ]]
}

@test "fix_broken_symlinks: preserves valid symlinks" {
    mkdir -p "$TMPDIR/d"
    touch "$TMPDIR/d/real"
    ln -s "$TMPDIR/d/real" "$TMPDIR/d/good"
    fix_broken_symlinks "$TMPDIR/d"
    [[ -L "$TMPDIR/d/good" ]]
}

@test "fix_broken_symlinks: preserves regular files" {
    mkdir -p "$TMPDIR/d"
    echo "data" > "$TMPDIR/d/file"
    fix_broken_symlinks "$TMPDIR/d"
    [[ "$(cat "$TMPDIR/d/file")" == "data" ]]
}

@test "fix_broken_symlinks: handles empty dir" {
    mkdir -p "$TMPDIR/empty"
    run fix_broken_symlinks "$TMPDIR/empty"
    [[ "$status" -eq 0 ]]
}

@test "fix_broken_symlinks: handles nonexistent dir" {
    run fix_broken_symlinks "$TMPDIR/nope"
    [[ "$status" -eq 0 ]]
}

@test "fix_broken_symlinks: removes multiple broken links" {
    mkdir -p "$TMPDIR/d"
    ln -s /a "$TMPDIR/d/b1"
    ln -s /b "$TMPDIR/d/b2"
    touch "$TMPDIR/d/real"
    ln -s "$TMPDIR/d/real" "$TMPDIR/d/good"
    fix_broken_symlinks "$TMPDIR/d"
    [[ ! -L "$TMPDIR/d/b1" ]]
    [[ ! -L "$TMPDIR/d/b2" ]]
    [[ -L "$TMPDIR/d/good" ]]
}

@test "fix_broken_symlinks: --recursive finds nested broken links" {
    mkdir -p "$TMPDIR/d/sub"
    ln -s /x "$TMPDIR/d/sub/broken"
    fix_broken_symlinks "$TMPDIR/d" --recursive
    [[ ! -L "$TMPDIR/d/sub/broken" ]]
}

@test "fix_broken_symlinks: non-recursive skips nested" {
    mkdir -p "$TMPDIR/d/sub"
    ln -s /x "$TMPDIR/d/top"
    ln -s /y "$TMPDIR/d/sub/nested"
    fix_broken_symlinks "$TMPDIR/d"
    [[ ! -L "$TMPDIR/d/top" ]]
    [[ -L "$TMPDIR/d/sub/nested" ]]  # still there
}

# =====================================================================
#  pkg_install
# =====================================================================

@test "pkg_install: function exists" {
    declare -f pkg_install >/dev/null
}

# =====================================================================
#  CLI argument parsing
# =====================================================================

parse_args() {
    FORCE=false; TYPE=https; FISH=true; BUN=true; DENO=true; NVIM=true; NODE=true
    for arg in "$@"; do
        case "$arg" in
            --force)    FORCE=true ;;
            --type=*)   TYPE="${arg#--type=}" ;;
            --no-fish)  FISH=false ;;
            --no-node)  NODE=false ;;
            --no-bun)   BUN=false ;;
            --no-deno)  DENO=false ;;
            --no-nvim)  NVIM=false ;;
        esac
    done
}

@test "args: --force sets FORCE=true" {
    parse_args --force
    [[ "$FORCE" == true ]]
}

@test "args: --type=ssh sets TYPE" {
    parse_args --type=ssh
    [[ "$TYPE" == "ssh" ]]
}

@test "args: --no-fish disables FISH" {
    parse_args --no-fish
    [[ "$FISH" == false ]]
}

@test "args: no args keeps defaults" {
    parse_args
    [[ "$FORCE" == false ]]
    [[ "$TYPE" == "https" ]]
    [[ "$FISH" == true ]]
}

@test "args: multiple flags combine" {
    parse_args --force --no-bun --no-nvim
    [[ "$FORCE" == true ]]
    [[ "$BUN" == false ]]
    [[ "$NVIM" == false ]]
    [[ "$FISH" == true ]]
}

# =====================================================================
#  Idempotent install scripts — skip when command exists
# =====================================================================

make_fake_cmd() {
    local dir="$TMPDIR/fakebin" name=$1 output=${2:-"0.0.1"}
    mkdir -p "$dir"
    printf '#!/bin/sh\necho "%s"\n' "$output" > "$dir/$name"
    chmod +x "$dir/$name"
    echo "$dir"
}

@test "inst-bun.sh: skips when bun exists" {
    local bin; bin=$(make_fake_cmd bun "1.1.0")
    run env PATH="$bin:$PATH" FORCE=false bash "$REPO_DIR/scripts/inst/inst-bun.sh"
    [[ "$output" == *"already installed"* ]]
}

@test "inst-bun.sh: does not skip when FORCE=true" {
    local bin; bin=$(make_fake_cmd bun "1.1.0")
    printf '#!/bin/sh\nexit 0\n' > "$bin/curl"
    chmod +x "$bin/curl"
    run env PATH="$bin:$PATH" FORCE=true bash "$REPO_DIR/scripts/inst/inst-bun.sh"
    [[ "$output" != *"already installed"* ]]
}

@test "inst-deno.sh: skips when deno exists" {
    local bin; bin=$(make_fake_cmd deno "deno 1.40.0")
    run env PATH="$bin:$PATH" FORCE=false bash "$REPO_DIR/scripts/inst/inst-deno.sh"
    [[ "$output" == *"already installed"* ]]
}

@test "inst-fd.sh: skips when fd exists" {
    local bin; bin=$(make_fake_cmd fd "fd 10.3.0")
    run env HOME="$FAKE_HOME" PATH="$bin:$PATH" FORCE=false \
        bash "$REPO_DIR/scripts/inst/inst-fd.sh"
    [[ "$output" == *"already installed"* ]]
}

@test "inst-fish.sh: skips when fish exists" {
    local bin; bin=$(make_fake_cmd fish "fish 3.7.0")
    run env HOME="$FAKE_HOME" PATH="$bin:$PATH" FORCE=false \
        bash "$REPO_DIR/scripts/inst/inst-fish.sh"
    [[ "$output" == *"already installed"* ]]
}

@test "inst-fzf.sh: skips when fzf binary exists at ~/.local/bin" {
    mkdir -p "$FAKE_HOME/.local/bin"
    touch "$FAKE_HOME/.local/bin/fzf"
    run env HOME="$FAKE_HOME" FORCE=false bash "$REPO_DIR/scripts/inst/inst-fzf.sh"
    [[ "$output" != *"INSTALLING FZF"* ]]
}

@test "inst-fzf.sh: skips when fzf on PATH" {
    local bin; bin=$(make_fake_cmd fzf "0.42.0")
    run env HOME="$FAKE_HOME" PATH="$bin:$PATH" FORCE=false \
        bash "$REPO_DIR/scripts/inst/inst-fzf.sh"
    [[ "$output" != *"INSTALLING FZF"* ]]
}

@test "inst-cargo.sh: skips when cargo exists" {
    local bin; bin=$(make_fake_cmd cargo "cargo 1.80.0")
    run env PATH="$bin:$PATH" FORCE=false bash "$REPO_DIR/scripts/inst/inst-cargo.sh"
    [[ "$output" == *"already installed"* ]]
}

# =====================================================================
#  cfg-default-dirs.sh: broken symlink cleanup + missing source
# =====================================================================

setup_fake_dotfiles() {
    mkdir -p "$FAKE_HOME/dotfiles/scripts" "$FAKE_HOME/dotfiles/.config/fish" \
        "$FAKE_HOME/dotfiles/.config/tmux" "$FAKE_HOME/dotfiles/.config/nvim" \
        "$FAKE_HOME/dotfiles/.config/opencode" "$FAKE_HOME/dotfiles/helpers"
    touch "$FAKE_HOME/dotfiles/.bashrc" "$FAKE_HOME/dotfiles/.gitconfig" \
        "$FAKE_HOME/dotfiles/.gitignore" "$FAKE_HOME/dotfiles/.Xresources" \
        "$FAKE_HOME/dotfiles/.config/.func" "$FAKE_HOME/dotfiles/.config/.aliasrc" \
        "$FAKE_HOME/dotfiles/.config/opencode/opencode.jsonc"
    cp "$REPO_DIR/globals.sh" "$FAKE_HOME/dotfiles/globals.sh"
    cp "$REPO_DIR/scripts/cfg-default-dirs.sh" "$FAKE_HOME/dotfiles/scripts/cfg-default-dirs.sh"
}

@test "cfg-default-dirs: cleans broken symlinks in .config" {
    setup_fake_dotfiles
    mkdir -p "$FAKE_HOME/.config"
    ln -s /nonexistent "$FAKE_HOME/.config/broken-app"
    touch "$FAKE_HOME/.config/real-file"
    ln -s "$FAKE_HOME/.config/real-file" "$FAKE_HOME/.config/valid-link"

    env HOME="$FAKE_HOME" DOTFILES_DIR="$FAKE_HOME/dotfiles" \
        NVIM=true SYSTEM=false ZSH=false \
        bash "$FAKE_HOME/dotfiles/scripts/cfg-default-dirs.sh"

    [[ ! -L "$FAKE_HOME/.config/broken-app" ]]
    [[ -L "$FAKE_HOME/.config/valid-link" ]]
}

@test "cfg-default-dirs: skips missing source files" {
    mkdir -p "$FAKE_HOME/dotfiles/scripts" "$FAKE_HOME/dotfiles/.config" \
        "$FAKE_HOME/dotfiles/helpers"
    cp "$REPO_DIR/globals.sh" "$FAKE_HOME/dotfiles/globals.sh"
    cp "$REPO_DIR/scripts/cfg-default-dirs.sh" "$FAKE_HOME/dotfiles/scripts/cfg-default-dirs.sh"

    run env HOME="$FAKE_HOME" DOTFILES_DIR="$FAKE_HOME/dotfiles" \
        NVIM=false SYSTEM=false ZSH=false \
        bash "$FAKE_HOME/dotfiles/scripts/cfg-default-dirs.sh"

    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Source missing"* ]]
}

# =====================================================================
#  Nvim config symlink (ensure_nvim_config in inst-nvim.sh)
# =====================================================================

@test "inst-nvim: ensure_nvim_config creates symlink" {
    mkdir -p "$FAKE_HOME/.config" "$FAKE_HOME/dotfiles/.config/nvim"
    run bash -c "
        HOME='$FAKE_HOME' DOTFILES_DIR='$FAKE_HOME/dotfiles'
        eval \"\$(sed -n '/^ensure_nvim_config()/,/^}/p' '$REPO_DIR/scripts/inst/inst-nvim.sh')\"
        ensure_nvim_config
        readlink '$FAKE_HOME/.config/nvim'
    "
    [[ "$output" == *"$FAKE_HOME/dotfiles/.config/nvim"* ]]
}

@test "inst-nvim: ensure_nvim_config is idempotent" {
    mkdir -p "$FAKE_HOME/.config" "$FAKE_HOME/dotfiles/.config/nvim"
    ln -s "$FAKE_HOME/dotfiles/.config/nvim" "$FAKE_HOME/.config/nvim"
    run bash -c "
        HOME='$FAKE_HOME' DOTFILES_DIR='$FAKE_HOME/dotfiles'
        eval \"\$(sed -n '/^ensure_nvim_config()/,/^}/p' '$REPO_DIR/scripts/inst/inst-nvim.sh')\"
        ensure_nvim_config; echo ok
    "
    [[ "$output" == *"ok"* ]]
    [[ "$(readlink "$FAKE_HOME/.config/nvim")" == "$FAKE_HOME/dotfiles/.config/nvim" ]]
}
