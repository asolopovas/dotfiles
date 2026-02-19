#!/usr/bin/env bats

# ---------------------------------------------------------------------------
# Standard sudoer user suite.
# Entrypoint runs:  init.sh as stduser (installs bun, deno, fd, fzf, node,
#                   nvim, composer, omf, cfg-default-dirs, etc.)
# Then this file runs two groups:
#   A) Bootstrap result assertions (did init.sh produce the right state?)
#   B) Script unit tests (do individual scripts work correctly?)
# ---------------------------------------------------------------------------

H="/home/stduser"
D="$H/dotfiles"

# =======================================================================
#  A) BOOTSTRAP RESULT ASSERTIONS
# =======================================================================

# ---- dotfiles clone ----

@test "bootstrap: dotfiles cloned" {
    [ -d "$D/.git" ]
    [ -f "$D/globals.sh" ]
    [ -f "$D/init.sh" ]
}

@test "bootstrap: globals.sh sources" {
    run sudo -u stduser bash -c "source $D/globals.sh"
    [ "$status" -eq 0 ]
}

@test "bootstrap: essential dirs" {
    [ -d "$H/.config" ]
    [ -d "$H/.local/bin" ]
    [ -d "$H/.tmp" ]
}

# ---- cfg-default-dirs results ----

@test "bootstrap: .bashrc symlinked" {
    [ -L "$H/.bashrc" ]
    [[ "$(readlink "$H/.bashrc")" == */dotfiles/.bashrc ]]
}

@test "bootstrap: .gitconfig symlinked" {
    [ -L "$H/.gitconfig" ]
}

@test "bootstrap: .gitignore symlinked" {
    [ -L "$H/.gitignore" ]
}

@test "bootstrap: fish config symlinked" {
    [ -L "$H/.config/fish" ]
}

@test "bootstrap: tmux config symlinked" {
    [ -L "$H/.config/tmux" ]
}

@test "bootstrap: helpers symlinked" {
    [ -L "$H/.local/bin/helpers" ]
}

@test "bootstrap: src dir" {
    [ -d "$H/src" ]
}

@test "bootstrap: .cache dir" {
    [ -d "$H/.cache" ]
}

# ---- composer ----

@test "bootstrap: composer installed" {
    [ -f "$H/.local/bin/composer" ]
    [ -x "$H/.local/bin/composer" ]
}

# ---- bun ----

@test "bootstrap: bun installed" {
    [ -d "$H/.bun" ]
    [ -x "$H/.bun/bin/bun" ]
}

@test "bootstrap: bun runs" {
    run sudo -u stduser "$H/.bun/bin/bun" --version
    [ "$status" -eq 0 ]
}

# ---- deno ----

@test "bootstrap: deno installed" {
    [ -x "$H/.deno/bin/deno" ]
}

@test "bootstrap: deno runs" {
    run sudo -u stduser "$H/.deno/bin/deno" --version
    [ "$status" -eq 0 ]
    [[ "$output" == *"deno"* ]]
}

# ---- fd ----

@test "bootstrap: fd installed" {
    [ -x "$H/.local/bin/fd" ]
}

@test "bootstrap: fd runs" {
    run sudo -u stduser "$H/.local/bin/fd" --version
    [ "$status" -eq 0 ]
}

# ---- fzf ----

@test "bootstrap: fzf installed" {
    [ -x "$H/.local/bin/fzf" ]
}

@test "bootstrap: fzf runs" {
    run sudo -u stduser "$H/.local/bin/fzf" --version
    [ "$status" -eq 0 ]
}

# ---- node (volta) ----

@test "bootstrap: volta installed" {
    [ -d "$H/.volta" ]
    [ -x "$H/.volta/bin/volta" ]
}

@test "bootstrap: node runs" {
    run sudo -u stduser env HOME="$H" PATH="$H/.volta/bin:$PATH" \
        volta run node --version
    [ "$status" -eq 0 ]
    [[ "$output" == v* ]]
}

# ---- nvim ----

@test "bootstrap: nvim installed" {
    [ -x "$H/.local/nvim/bin/nvim" ]
}

@test "bootstrap: nvim runs" {
    run sudo -u stduser "$H/.local/nvim/bin/nvim" --version
    [ "$status" -eq 0 ]
    [[ "${lines[0]}" == *"NVIM"* ]]
}

@test "bootstrap: vim symlink" {
    [ -L "$H/.local/bin/vim" ] || [ -f "$H/.local/bin/vim" ]
}

@test "bootstrap: nvim config symlinked" {
    [ -L "$H/.config/nvim" ]
    [[ "$(readlink "$H/.config/nvim")" == */dotfiles/.config/nvim ]]
}

# ---- omf ----

@test "bootstrap: omf installed" {
    [ -d "$H/.local/share/omf" ]
    [ -f "$H/.local/share/omf/init.fish" ]
}

# ---- idempotency ----

@test "bootstrap: second init.sh succeeds" {
    [ -d /etc/psa ] && sudo mv /etc/psa /etc/psa.hidden
    run sudo -u stduser env HOME="$H" CHANGE_SHELL=false bash "$D/init.sh"
    [ -d /etc/psa.hidden ] && sudo mv /etc/psa.hidden /etc/psa
    [ "$status" -eq 0 ]
}

# =======================================================================
#  B) SCRIPT UNIT TESTS
# =======================================================================

# ---- globals.sh ----

@test "globals: exports DOTFILES_DIR" {
    run sudo -u stduser bash -c "export HOME=$H; source $D/globals.sh; echo \$DOTFILES_DIR"
    [[ "$output" == */dotfiles ]]
}

@test "globals: exports OS as ubuntu" {
    run sudo -u stduser bash -c "export HOME=$H; source $D/globals.sh; echo \$OS"
    [ "$output" = "ubuntu" ]
}

@test "globals: cmd_exist finds bash" {
    run sudo -u stduser bash -c "source $D/globals.sh; cmd_exist bash && echo yes"
    [[ "$output" == *"yes"* ]]
}

@test "globals: cmd_exist rejects nonexistent" {
    run sudo -u stduser bash -c "source $D/globals.sh; cmd_exist no_such_cmd_42"
    [ "$status" -ne 0 ]
}

@test "globals: print_color outputs text" {
    run sudo -u stduser bash -c "source $D/globals.sh; print_color green hello"
    [[ "$output" == *"hello"* ]]
}

@test "globals: create_dir" {
    local d="/tmp/bats-createdir-$$"
    run sudo -u stduser bash -c "source $D/globals.sh; create_dir '$d'; [ -d '$d' ] && echo ok"
    [[ "$output" == *"ok"* ]]
    rm -rf "$d"
}

@test "globals: load_env_vars" {
    local f="/tmp/bats-env-$$"
    echo "BATS_KEY=bats42" > "$f"; chmod 644 "$f"
    run sudo -u stduser bash -c "source $D/globals.sh; load_env_vars '$f'; echo \$BATS_KEY"
    [[ "$output" == *"bats42"* ]]
    rm -f "$f"
}

@test "globals: load_env_vars skips set vars" {
    local f="/tmp/bats-envskip-$$"
    echo "HOME=/wrong" > "$f"; chmod 644 "$f"
    run sudo -u stduser bash -c "export HOME=$H; source $D/globals.sh; load_env_vars '$f'; echo \$HOME"
    [[ "$output" != "/wrong" ]]
    rm -f "$f"
}

# ---- ops-update-symlinks.sh ----

@test "ops-update-symlinks: creates symlinks" {
    sudo -u stduser bash -c "
        rm -rf $H/.config/fish $H/.config/nvim $H/.config/tmux $H/.claude
        rm -f $H/.config/.aliasrc $H/.config/.func
    "
    run sudo -u stduser env HOME="$H" DOTFILES_DIR="$D" bash "$D/scripts/ops-update-symlinks.sh"
    [ "$status" -eq 0 ]
    [ -L "$H/.config/fish" ]
    [ -L "$H/.config/nvim" ]
    [ -L "$H/.config/tmux" ]
    [ -L "$H/.config/.aliasrc" ]
    [ -L "$H/.config/.func" ]
}

@test "ops-update-symlinks: targets point to repo" {
    local target
    target=$(readlink "$H/.config/nvim")
    [[ "$target" == */dotfiles/.config/nvim ]]
}

@test "ops-update-symlinks: idempotent" {
    run sudo -u stduser env HOME="$H" DOTFILES_DIR="$D" bash "$D/scripts/ops-update-symlinks.sh"
    [ "$status" -eq 0 ]
    run sudo -u stduser env HOME="$H" DOTFILES_DIR="$D" bash "$D/scripts/ops-update-symlinks.sh"
    [ "$status" -eq 0 ]
}

@test "ops-update-symlinks: rejects XDG inside repo" {
    run sudo -u stduser env HOME="$H" DOTFILES_DIR="$D" XDG_CONFIG_HOME="$D/.config" \
        bash "$D/scripts/ops-update-symlinks.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Refusing"* ]]
}

# ---- cfg-locale.sh ----

@test "cfg-locale: generates locale" {
    run bash "$D/scripts/cfg-locale.sh" en_US.UTF-8
    [ "$status" -eq 0 ]
    run locale -a
    [[ "$output" == *"en_US.utf8"* ]]
}

@test "cfg-locale: idempotent" {
    run bash "$D/scripts/cfg-locale.sh" en_US.UTF-8
    [ "$status" -eq 0 ]
    # Script succeeds on re-run (either "already set" or re-generates)
    [[ "$output" == *"already set"* ]] || [[ "$output" == *"setup complete"* ]]
}

@test "cfg-locale: default is en_GB" {
    run bash "$D/scripts/cfg-locale.sh"
    [ "$status" -eq 0 ]
    run locale -a
    [[ "$output" == *"en_GB.utf8"* ]]
}

# ---- fix-locale.sh ----

@test "fix-locale: generates en_GB" {
    run bash "$D/scripts/fix-locale.sh"
    [ "$status" -eq 0 ]
    run locale -a
    [[ "$output" == *"en_GB.utf8"* ]]
}

# ---- cfg-dev-tools-proxy.sh (--remove only) ----

@test "cfg-dev-tools-proxy --remove: cleans config" {
    mkdir -p /tmp/proxy-test-home/.pip /tmp/proxy-test-home/.config/pip
    echo "x" > /tmp/proxy-test-home/.wgetrc
    echo "x" > /tmp/proxy-test-home/.curlrc
    echo "x" > /tmp/proxy-test-home/.pip/pip.conf
    echo "x" > /tmp/proxy-test-home/.config/pip/pip.conf

    run env HOME=/tmp/proxy-test-home bash "$D/scripts/cfg-dev-tools-proxy.sh" --remove
    [ "$status" -eq 0 ]
    [ ! -f /tmp/proxy-test-home/.wgetrc ]
    [ ! -f /tmp/proxy-test-home/.curlrc ]
    [ ! -f /tmp/proxy-test-home/.pip/pip.conf ]
    [ ! -f /tmp/proxy-test-home/.config/pip/pip.conf ]
    rm -rf /tmp/proxy-test-home
}

# ---- cfg-default-dirs.sh (direct run, idempotent) ----

@test "cfg-default-dirs: idempotent re-run" {
    run sudo -u stduser bash -c "
        export HOME=$H NVIM=false SYSTEM=false ZSH=false
        source $D/globals.sh
        source $D/scripts/cfg-default-dirs.sh
    "
    [ "$status" -eq 0 ]
    [ -L "$H/.bashrc" ]
    [ -L "$H/.local/bin/helpers" ]
}
