#!/usr/bin/env bats

# ---------------------------------------------------------------------------
# Plesk ROOT assertions — after: init.sh -> plesk-init.sh all
# Tests shared installs at /opt/*, /usr/local/bin/*, /etc/*.
# ---------------------------------------------------------------------------

setup_file() {
    if [ ! -d /opt/dotfiles ]; then
        echo "ERROR: plesk-init.sh must run before these tests" >&2
        return 1
    fi
}

# ===== init.sh bootstrap =====

@test "plesk: dotfiles present at ~/dotfiles" {
    [ -d "$HOME/dotfiles" ]
    [ -f "$HOME/dotfiles/globals.sh" ]
    [ -f "$HOME/dotfiles/init.sh" ]
}

@test "plesk: globals.sh sources" {
    run bash -c "source $HOME/dotfiles/globals.sh"
    [ "$status" -eq 0 ]
}

@test "plesk: essential dirs created" {
    [ -d "$HOME/.config" ]
    [ -d "$HOME/.local/bin" ]
}

@test "plesk: delegated to plesk-init.sh" {
    [ -d /opt/dotfiles ]
}

# ===== dotfiles section =====

@test "plesk-dotfiles: /opt/dotfiles synced" {
    [ -f /opt/dotfiles/globals.sh ]
    [ -f /opt/dotfiles/init.sh ]
    [ -d /opt/dotfiles/scripts ]
}

@test "plesk-dotfiles: .git excluded" {
    [ ! -d /opt/dotfiles/.git ]
}

@test "plesk-dotfiles: root-owned world-readable" {
    [ "$(stat -c '%U' /opt/dotfiles)" = "root" ]
    run stat -c '%A' /opt/dotfiles
    [[ "$output" == *"r-x" ]]
}

# ===== omf section =====

@test "plesk-omf: installed" {
    [ -f /opt/omf/init.fish ]
}

@test "plesk-omf: bass plugin" {
    [ -d /opt/omf/pkg/bass ]
}

@test "plesk-omf: .git dirs stripped" {
    local count
    count=$(find /opt/omf -name ".git" -type d 2>/dev/null | wc -l)
    [ "$count" -eq 0 ]
}

@test "plesk-omf: root-owned" {
    [ "$(stat -c '%U' /opt/omf)" = "root" ]
}

# ===== nvim section =====

@test "plesk-nvim: binary at /opt/nvim/bin/nvim" {
    [ -x /opt/nvim/bin/nvim ]
}

@test "plesk-nvim: version output" {
    run /opt/nvim/bin/nvim --version
    [ "$status" -eq 0 ]
    [[ "${lines[0]}" == *"NVIM"* ]]
}

@test "plesk-nvim: wrapper at /usr/local/bin/nvim" {
    [ -x /usr/local/bin/nvim ]
    run cat /usr/local/bin/nvim
    [[ "$output" != *"XDG_CONFIG_HOME="* ]]
    [[ "$output" == *"XDG_DATA_HOME=/opt/nvim-data"* ]]
    [[ "$output" == *"XDG_STATE_HOME"* ]]
    [[ "$output" == *"mkdir -p"* ]]
}

@test "plesk-nvim: vim symlink" {
    [ -L /usr/local/bin/vim ]
    [ "$(readlink /usr/local/bin/vim)" = "/usr/local/bin/nvim" ]
}

@test "plesk-nvim: config at /opt/nvim-config/nvim" {
    [ -f /opt/nvim-config/nvim/init.lua ]
}

@test "plesk-nvim: lazy plugins installed" {
    [ -d /opt/nvim-data/nvim/lazy ]
    [ -d /opt/nvim-data/nvim/lazy/lazy.nvim ]
    [ -d /opt/nvim-data/nvim/lazy/telescope.nvim ]
    [ -d /opt/nvim-data/nvim/lazy/plenary.nvim ]
}

@test "plesk-nvim: treesitter parsers" {
    local count
    count=$(find /opt/nvim-data -name "*.so" -path "*/parser/*" 2>/dev/null | wc -l)
    [ "$count" -gt 0 ]
}

@test "plesk-nvim: mason dir exists" {
    [ -d /opt/nvim-data/nvim/mason ]
}

@test "plesk-nvim: shared data root-owned" {
    [ "$(stat -c '%U' /opt/nvim-data)" = "root" ]
}

@test "plesk-nvim: stale profile.d removed" {
    [ ! -f /etc/profile.d/nvim.sh ]
}

# ===== bun section =====

@test "plesk-bun: bun-bin installed" {
    [ -x /usr/local/bin/bun-bin ]
    run /usr/local/bin/bun-bin --version
    [ "$status" -eq 0 ]
}

@test "plesk-bun: wrapper installed" {
    [ -x /usr/local/bin/bun ]
    run cat /usr/local/bin/bun
    [[ "$output" == *"BUN_INSTALL_CACHE_DIR"* ]]
    [[ "$output" == *"sudo /usr/local/bin/bun-run"* ]]
}

@test "plesk-bun: bun-run helper" {
    [ -x /usr/local/bin/bun-run ]
    run cat /usr/local/bin/bun-run
    [[ "$output" == *"BUN_INSTALL_CACHE_DIR"* ]]
    [[ "$output" == *"chown"* ]]
}

@test "plesk-bun: bunx symlink" {
    [ -L /usr/local/bin/bunx ]
}

@test "plesk-bun: shared cache dir" {
    [ -d /var/www/bun-cache ]
}

@test "plesk-bun: sudoers valid" {
    [ -f /etc/sudoers.d/bun-cache ]
    run visudo -cf /etc/sudoers.d/bun-cache
    [ "$status" -eq 0 ]
}

@test "plesk-bun: profile env" {
    [ -f /etc/profile.d/bun.sh ]
    run grep BUN_INSTALL_CACHE_DIR /etc/profile.d/bun.sh
    [ "$status" -eq 0 ]
}

# ===== sync mode =====

@test "plesk-sync: updates shared config" {
    echo "# test-marker-$(date +%s)" >> /root/dotfiles/globals.sh
    run bash /root/dotfiles/scripts/plesk-init.sh sync
    [ "$status" -eq 0 ]
    run grep "test-marker" /opt/dotfiles/globals.sh
    [ "$status" -eq 0 ]
    sed -i '/test-marker/d' /root/dotfiles/globals.sh
}

# ===== idempotency =====

@test "plesk-idempotent: second run succeeds" {
    run bash /root/dotfiles/scripts/plesk-init.sh all
    [ "$status" -eq 0 ]
}

@test "plesk-idempotent: state intact" {
    [ -d /opt/dotfiles ]
    [ -x /opt/nvim/bin/nvim ]
    [ -x /usr/local/bin/bun-bin ]
}
