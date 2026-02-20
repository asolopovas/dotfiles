#!/usr/bin/env bats

# ---------------------------------------------------------------------------
# Plesk VHOST user assertions — runs after plesk-init.sh.
# Tests per-user symlinks, ownership, fish config, omf, nvim for
# testuser1 (/var/www/vhosts/test1.com) and testuser2 (test2.org).
# ---------------------------------------------------------------------------

setup_file() {
    if [ ! -d /opt/dotfiles ] || [ ! -L /var/www/vhosts/test1.com/dotfiles ]; then
        echo "ERROR: plesk-init.sh must run before vhost tests" >&2
        return 1
    fi
}

# ===== testuser1 dotfiles =====

@test "vhost1: dotfiles -> /opt/dotfiles" {
    local h="/var/www/vhosts/test1.com"
    [ -L "$h/dotfiles" ]
    [ "$(readlink "$h/dotfiles")" = "/opt/dotfiles" ]
}

@test "vhost1: symlink owned by vhost user" {
    [ "$(stat -c '%U' /var/www/vhosts/test1.com/dotfiles)" = "testuser1" ]
}

# ===== config symlinks =====

@test "vhost1: config symlinks" {
    local h="/var/www/vhosts/test1.com"
    [ -L "$h/.bashrc" ]
    [ -L "$h/.gitconfig" ]
    [ -L "$h/.gitignore" ]
    [ -L "$h/.config/tmux" ]
    [ -L "$h/.config/.func" ]
    [ -L "$h/.config/.aliasrc" ]
}

@test "vhost1: helpers symlinked" {
    [ -L "/var/www/vhosts/test1.com/.local/bin/helpers" ]
}

# ===== base directories =====

@test "vhost1: base dirs exist" {
    local h="/var/www/vhosts/test1.com"
    [ -d "$h/.config" ]
    [ -d "$h/.local/bin" ]
    [ -d "$h/.local/share" ]
    [ -d "$h/.local/state/nvim" ]
    [ -d "$h/.cache/nvim" ]
}

@test "vhost1: state/cache owned by vhost user" {
    local h="/var/www/vhosts/test1.com"
    [ "$(stat -c '%U' "$h/.local/state")" = "testuser1" ]
    [ "$(stat -c '%U' "$h/.cache/nvim")" = "testuser1" ]
}

# ===== fish config =====

@test "vhost1: fish config is real dir" {
    local h="/var/www/vhosts/test1.com"
    [ -d "$h/.config/fish" ]
    [ ! -L "$h/.config/fish" ]
}

@test "vhost1: fish shared items symlinked" {
    local h="/var/www/vhosts/test1.com"
    [ -L "$h/.config/fish/config.fish" ]
    [ -L "$h/.config/fish/functions" ]
    [ -L "$h/.config/fish/conf.d" ]
    [ -L "$h/.config/fish/completions" ]
}

@test "vhost1: fish_variables per-user writable" {
    local h="/var/www/vhosts/test1.com"
    [ -f "$h/.config/fish/fish_variables" ]
    [ ! -L "$h/.config/fish/fish_variables" ]
    [ "$(stat -c '%U' "$h/.config/fish/fish_variables")" = "testuser1" ]
}

# ===== omf =====

@test "vhost1: omf -> /opt/omf" {
    local h="/var/www/vhosts/test1.com"
    [ -L "$h/.local/share/omf" ]
    [ "$(readlink "$h/.local/share/omf")" = "/opt/omf" ]
}

@test "vhost1: omf config per-user writable" {
    local h="/var/www/vhosts/test1.com"
    [ -d "$h/.config/omf" ]
    [ -f "$h/.config/omf/bundle" ]
    [ "$(stat -c '%U' "$h/.config/omf")" = "testuser1" ]
}

# ===== nvim =====

@test "vhost1: nvim config -> shared" {
    local h="/var/www/vhosts/test1.com"
    [ -L "$h/.config/nvim" ]
    [ "$(readlink "$h/.config/nvim")" = "/opt/nvim-config/nvim" ]
}

@test "vhost1: stale per-user dirs absent" {
    local h="/var/www/vhosts/test1.com"
    [ ! -d "$h/.local/nvim" ]
    [ ! -d "$h/.local/share/nvim" ]
    [ ! -d "$h/.bun" ]
}

# ===== opencode =====

@test "vhost1: opencode config -> shared" {
    local h="/var/www/vhosts/test1.com"
    if [ ! -d /opt/opencode-config ]; then skip "no opencode config"; fi
    [ -L "$h/.config/opencode" ]
    [ "$(readlink "$h/.config/opencode")" = "/opt/opencode-config" ]
}

@test "vhost1: opencode cache -> shared" {
    local h="/var/www/vhosts/test1.com"
    if [ ! -d /opt/opencode-cache ]; then skip "no opencode cache"; fi
    [ -L "$h/.cache/opencode" ]
    [ "$(readlink "$h/.cache/opencode")" = "/opt/opencode-cache" ]
}

@test "vhost1: opencode bin -> shared" {
    local h="/var/www/vhosts/test1.com"
    if [ ! -d /opt/opencode-bin ]; then skip "no opencode bin"; fi
    [ -L "$h/.local/share/opencode/bin" ]
    [ "$(readlink "$h/.local/share/opencode/bin")" = "/opt/opencode-bin" ]
}

@test "vhost1: vscode-server -> shared" {
    local h="/var/www/vhosts/test1.com"
    if [ ! -d /opt/vscode-server ]; then skip "no vscode-server"; fi
    [ -L "$h/.vscode-server" ]
    [ "$(readlink "$h/.vscode-server")" = "/opt/vscode-server" ]
}

@test "vhost1: plesk node/php binaries symlinked" {
    local h="/var/www/vhosts/test1.com"
    [ -L "$h/.local/bin/node" ] || [ -L "$h/.local/bin/php" ]
}

# ===== nvim wrapper =====

@test "vhost1-nvim: wrapper creates state dirs" {
    local h="/var/www/vhosts/test1.com"
    # The wrapper does mkdir -p for these on launch; verify the wrapper script itself
    run cat /usr/local/bin/nvim
    [[ "$output" == *'mkdir -p "$HOME/.local/state/nvim" "$HOME/.cache/nvim"'* ]]
}

@test "vhost1-nvim: shared data read-only for vhost user" {
    run sudo -u testuser1 bash -c 'touch /opt/nvim-data/nvim/test_write 2>&1'
    [ "$status" -ne 0 ]
}

# ===== testuser2 spot check =====

@test "vhost2: full setup" {
    local h="/var/www/vhosts/test2.org"
    [ -L "$h/dotfiles" ]
    [ -L "$h/.bashrc" ]
    [ -d "$h/.config/fish" ]
    [ ! -L "$h/.config/fish" ]
    [ -L "$h/.local/share/omf" ]
    [ -d "$h/.local/state/nvim" ]
    [ -d "$h/.cache/nvim" ]
    [ "$(stat -c '%U' "$h/.local/state")" = "testuser2" ]
}

@test "vhost2: dotfiles -> /opt/dotfiles" {
    local h="/var/www/vhosts/test2.org"
    [ -L "$h/dotfiles" ]
    [ "$(readlink "$h/dotfiles")" = "/opt/dotfiles" ]
}

@test "vhost2: symlink owned by vhost user" {
    [ "$(stat -c '%U' /var/www/vhosts/test2.org/dotfiles)" = "testuser2" ]
}

# ===== idempotency (vhost state after second plesk-init run) =====

@test "vhost: state intact after idempotent run" {
    [ -L /var/www/vhosts/test1.com/dotfiles ]
    [ -L /var/www/vhosts/test2.org/dotfiles ]
}
