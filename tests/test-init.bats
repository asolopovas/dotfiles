#!/usr/bin/env bats

# ---------------------------------------------------------------------------
# Full deployment tests for init.sh + plesk-init.sh
# Run inside Docker via: make test-init
#
# Flow: init.sh detects /etc/psa -> calls plesk-init.sh all -> exit
# So this tests the Plesk deployment path end-to-end.
# ---------------------------------------------------------------------------

setup_file() {
    # init.sh is run by the runner script before bats is invoked.
    # Verify the bootstrap completed before running assertions.
    if [ ! -d /opt/dotfiles ]; then
        echo "ERROR: init.sh must be run before tests" >&2
        return 1
    fi
}

# ===== init.sh bootstrap =====

@test "init: dotfiles present at ~/dotfiles" {
    [ -d "$HOME/dotfiles" ]
    [ -f "$HOME/dotfiles/globals.sh" ]
    [ -f "$HOME/dotfiles/init.sh" ]
}

@test "init: globals.sh sources without error" {
    run bash -c "source $HOME/dotfiles/globals.sh"
    [ "$status" -eq 0 ]
}

@test "init: essential dirs created" {
    [ -d "$HOME/.config" ]
    [ -d "$HOME/.local/bin" ]
}

@test "init: plesk detected and delegated to plesk-init.sh" {
    [ -d /opt/dotfiles ]
}

# ===== plesk-init.sh: dotfiles section =====

@test "plesk-dotfiles: /opt/dotfiles synced" {
    [ -f /opt/dotfiles/globals.sh ]
    [ -f /opt/dotfiles/init.sh ]
    [ -d /opt/dotfiles/scripts ]
}

@test "plesk-dotfiles: .git excluded from sync" {
    [ ! -d /opt/dotfiles/.git ]
}

@test "plesk-dotfiles: root-owned and world-readable" {
    [ "$(stat -c '%U' /opt/dotfiles)" = "root" ]
    # others can read
    run stat -c '%A' /opt/dotfiles
    [[ "$output" == *"r-x" ]]
}

# ===== plesk-init.sh: omf section =====

@test "plesk-omf: /opt/omf installed" {
    [ -f /opt/omf/init.fish ]
}

@test "plesk-omf: bass plugin present" {
    [ -d /opt/omf/pkg/bass ]
}

@test "plesk-omf: no .git dirs (stripped)" {
    local count
    count=$(find /opt/omf -name ".git" -type d 2>/dev/null | wc -l)
    [ "$count" -eq 0 ]
}

@test "plesk-omf: root-owned" {
    [ "$(stat -c '%U' /opt/omf)" = "root" ]
}

# ===== plesk-init.sh: nvim section =====

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
    [[ "$output" == *"XDG_CONFIG_HOME=/opt/nvim-config"* ]]
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

@test "plesk-nvim: treesitter parsers installed" {
    local count
    count=$(find /opt/nvim-data -name "*.so" -path "*/parser/*" 2>/dev/null | wc -l)
    [ "$count" -gt 0 ]
}

@test "plesk-nvim: mason dir exists" {
    [ -d /opt/nvim-data/nvim/mason ]
}

@test "plesk-nvim: shared data is root-owned read-only" {
    [ "$(stat -c '%U' /opt/nvim-data)" = "root" ]
}

@test "plesk-nvim: stale profile.d script removed" {
    [ ! -f /etc/profile.d/nvim.sh ]
}

# ===== plesk-init.sh: bun section =====

@test "plesk-bun: bun-bin installed" {
    [ -x /usr/local/bin/bun-bin ]
    run /usr/local/bin/bun-bin --version
    [ "$status" -eq 0 ]
}

@test "plesk-bun: bun wrapper installed" {
    [ -x /usr/local/bin/bun ]
    run cat /usr/local/bin/bun
    [[ "$output" == *"BUN_INSTALL_CACHE_DIR"* ]]
    [[ "$output" == *"sudo /usr/local/bin/bun-run"* ]]
}

@test "plesk-bun: bun-run helper installed" {
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

# ===== plesk-init.sh: vhosts section =====

@test "vhost: testuser1 dotfiles -> /opt/dotfiles" {
    local h="/var/www/vhosts/test1.com"
    [ -L "$h/dotfiles" ]
    [ "$(readlink "$h/dotfiles")" = "/opt/dotfiles" ]
}

@test "vhost: testuser2 dotfiles -> /opt/dotfiles" {
    local h="/var/www/vhosts/test2.org"
    [ -L "$h/dotfiles" ]
    [ "$(readlink "$h/dotfiles")" = "/opt/dotfiles" ]
}

@test "vhost: config symlinks created for testuser1" {
    local h="/var/www/vhosts/test1.com"
    [ -L "$h/.bashrc" ]
    [ -L "$h/.gitconfig" ]
    [ -L "$h/.gitignore" ]
    [ -L "$h/.config/tmux" ]
    [ -L "$h/.config/.func" ]
    [ -L "$h/.config/.aliasrc" ]
}

@test "vhost: helpers symlinked" {
    local h="/var/www/vhosts/test1.com"
    [ -L "$h/.local/bin/helpers" ]
}

@test "vhost: base dirs exist" {
    local h="/var/www/vhosts/test1.com"
    [ -d "$h/.config" ]
    [ -d "$h/.local/bin" ]
    [ -d "$h/.local/share" ]
    [ -d "$h/.local/state/nvim" ]
    [ -d "$h/.cache/nvim" ]
}

@test "vhost: state/cache dirs owned by vhost user" {
    local h="/var/www/vhosts/test1.com"
    [ "$(stat -c '%U' "$h/.local/state")" = "testuser1" ]
    [ "$(stat -c '%U' "$h/.cache/nvim")" = "testuser1" ]
}

@test "vhost: fish config is real dir (not symlink)" {
    local h="/var/www/vhosts/test1.com"
    [ -d "$h/.config/fish" ]
    [ ! -L "$h/.config/fish" ]
}

@test "vhost: fish shared items symlinked" {
    local h="/var/www/vhosts/test1.com"
    [ -L "$h/.config/fish/config.fish" ]
    [ -L "$h/.config/fish/functions" ]
    [ -L "$h/.config/fish/conf.d" ]
    [ -L "$h/.config/fish/completions" ]
}

@test "vhost: fish_variables is per-user writable file" {
    local h="/var/www/vhosts/test1.com"
    [ -f "$h/.config/fish/fish_variables" ]
    [ ! -L "$h/.config/fish/fish_variables" ]
    [ "$(stat -c '%U' "$h/.config/fish/fish_variables")" = "testuser1" ]
}

@test "vhost: omf symlink -> /opt/omf" {
    local h="/var/www/vhosts/test1.com"
    [ -L "$h/.local/share/omf" ]
    [ "$(readlink "$h/.local/share/omf")" = "/opt/omf" ]
}

@test "vhost: omf config per-user writable" {
    local h="/var/www/vhosts/test1.com"
    [ -d "$h/.config/omf" ]
    [ -f "$h/.config/omf/bundle" ]
    [ "$(stat -c '%U' "$h/.config/omf")" = "testuser1" ]
}

@test "vhost: plesk node/php binaries symlinked" {
    local h="/var/www/vhosts/test1.com"
    # Mock plesk has node and php binaries
    [ -L "$h/.local/bin/node" ] || [ -L "$h/.local/bin/php" ]
}

@test "vhost: stale per-user dirs absent" {
    local h="/var/www/vhosts/test1.com"
    [ ! -d "$h/.local/nvim" ]
    [ ! -d "$h/.local/share/nvim" ]
    [ ! -d "$h/.bun" ]
}

@test "vhost: symlink ownership is vhost user" {
    local h="/var/www/vhosts/test1.com"
    local owner
    owner=$(stat -c '%U' "$h/dotfiles")
    [ "$owner" = "testuser1" ]
}

# ===== Telescope history fix (the original bug) =====

@test "vhost-nvim: telescope history path is writable" {
    run sudo -u testuser1 \
        HOME="/var/www/vhosts/test1.com" \
        /usr/local/bin/nvim --headless -c 'lua
            local cfg = require("telescope.config").values
            local hp = cfg.history and cfg.history.path or "UNSET"
            print("path:" .. hp)
            local ok = pcall(function() require("plenary.path"):new(hp):touch() end)
            print("write:" .. tostring(ok))
            vim.cmd("qa!")
        ' 2>&1
    [[ "$output" == *"path:/var/www/vhosts/test1.com/.local/state/nvim/telescope_history"* ]]
    [[ "$output" == *"write:true"* ]]
}

@test "vhost-nvim: shared data is read-only for vhost user" {
    run sudo -u testuser1 bash -c 'touch /opt/nvim-data/nvim/test_write 2>&1'
    [ "$status" -ne 0 ]
}

@test "vhost-nvim: loads without errors as vhost user" {
    run sudo -u testuser1 \
        HOME="/var/www/vhosts/test1.com" \
        /usr/local/bin/nvim --headless -c 'lua
            local ok_ts = pcall(require, "telescope")
            local ok_lz = pcall(require, "lazy")
            print("telescope:" .. tostring(ok_ts))
            print("lazy:" .. tostring(ok_lz))
            vim.cmd("qa!")
        ' 2>&1
    [[ "$output" == *"telescope:true"* ]]
    [[ "$output" == *"lazy:true"* ]]
}

# ===== Sync mode =====

@test "plesk-sync: updates shared config" {
    echo "# test-marker-$(date +%s)" >> /root/dotfiles/globals.sh
    local marker
    marker=$(tail -1 /root/dotfiles/globals.sh)

    run bash /root/dotfiles/scripts/plesk-init.sh sync
    [ "$status" -eq 0 ]
    run grep "test-marker" /opt/dotfiles/globals.sh
    [ "$status" -eq 0 ]

    # Clean up
    sed -i '/test-marker/d' /root/dotfiles/globals.sh
}

# ===== Idempotency =====

@test "plesk-idempotent: second run succeeds" {
    run bash /root/dotfiles/scripts/plesk-init.sh all
    [ "$status" -eq 0 ]
}

@test "plesk-idempotent: state intact after second run" {
    [ -d /opt/dotfiles ]
    [ -x /opt/nvim/bin/nvim ]
    [ -x /usr/local/bin/bun-bin ]
    [ -L /var/www/vhosts/test1.com/dotfiles ]
    [ -L /var/www/vhosts/test2.org/dotfiles ]
}

# ===== Second vhost user spot check =====

@test "vhost: testuser2 has full setup" {
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
