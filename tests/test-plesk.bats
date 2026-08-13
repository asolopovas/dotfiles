#!/usr/bin/env bats

setup_file() {
    if [ ! -d /opt/dotfiles ]; then
        echo "plesk-init.sh must run before these tests" >&2
        return 1
    fi
}

@test "plesk: root bootstrap and shared dotfiles exist" {
    [ -d "$HOME/dotfiles" ]
    [ -f "$HOME/dotfiles/init.sh" ]
    run bash -c "source $HOME/dotfiles/globals.sh"
    [ "$status" -eq 0 ]
    [ -f /opt/dotfiles/globals.sh ]
    [ -f /opt/dotfiles/init.sh ]
    [ -d /opt/dotfiles/scripts ]
    [ -d /opt/dotfiles/agents/skills ]
    [ -d /opt/dotfiles/.git ]
    [ "$(stat -c '%U' /opt/dotfiles)" = "root" ]
}

@test "plesk: omf is shared and cleaned" {
    [ -f /opt/omf/init.fish ]
    [ -d /opt/omf/pkg/bass ]
    [ "$(stat -c '%U' /opt/omf)" = "root" ]
    [ "$(find /opt/omf -name .git -type d 2>/dev/null | wc -l)" -eq 0 ]
}

@test "plesk: nvim is shared through wrappers" {
    [ -x /opt/nvim/bin/nvim ]
    run /opt/nvim/bin/nvim --version
    [ "$status" -eq 0 ]
    [[ "${lines[0]}" == *"NVIM"* ]]
    [ -x /usr/local/bin/nvim ]
    [ -L /usr/local/bin/vim ]
    [ "$(readlink /usr/local/bin/vim)" = "/usr/local/bin/nvim" ]
    [ -f /opt/nvim-config/nvim/init.lua ]
    [ -d /opt/nvim-data/nvim/lazy/lazy.nvim ]
    [ -d /opt/nvim-data/nvim/mason ]
    [ ! -f /etc/profile.d/nvim.sh ]
}

@test "plesk: bun uses private user caches and pi wrapper is installed" {
    [ -x /usr/local/bin/bun-bin ]
    [ -x /usr/local/bin/bun ]
    [ -L /usr/local/bin/bunx ]
    [ ! -e /usr/local/bin/bun-run ]
    [ ! -e /etc/profile.d/bun.sh ]
    [ ! -e /etc/sudoers.d/bun-cache ]
    [ "$(stat -c '%U:%G' /usr/local/bin/bun)" = "root:root" ]
    [ "$(stat -c '%a' /usr/local/bin/bun)" = "755" ]
    run bash -n /usr/local/bin/bun
    [ "$status" -eq 0 ]
    run sudo -u stduser env -u XDG_CACHE_HOME HOME=/home/stduser /usr/local/bin/bun --version
    [ "$status" -eq 0 ]
    [ -d /home/stduser/.cache/bun ]
    [ "$(stat -c '%U:%G' /home/stduser/.cache/bun)" = "stduser:stduser" ]
    [ "$(stat -c '%a' /home/stduser/.cache/bun)" = "700" ]
    local shim_count=0
    while IFS= read -r -d '' shim_dir; do
        shim_count=$((shim_count + 1))
        [ "$(stat -c '%U:%G' "$shim_dir")" = "root:root" ]
        [ "$(stat -c '%a' "$shim_dir")" = "1777" ]
        [ "$(readlink "$shim_dir/bun")" = "/usr/local/bin/bun-bin" ]
        [ "$(readlink "$shim_dir/node")" = "/usr/local/bin/bun-bin" ]
        [ "$(stat -c '%U:%G' "$shim_dir/bun")" = "root:root" ]
        [ "$(stat -c '%U:%G' "$shim_dir/node")" = "root:root" ]
    done < <(find /tmp -maxdepth 1 -type d -name 'bun-node-*' -print0)
    [ "$shim_count" -gt 0 ]
    [ -x /usr/local/bin/pi ]
    [ -x /usr/local/sbin/pi-self-update ]
    run visudo -cf /etc/sudoers.d/pi-self-update
    [ "$status" -eq 0 ]
}

@test "plesk: ai config is shared" {
    [ -L /opt/opencode-config ]
    [ "$(readlink /opt/opencode-config)" = "/opt/dotfiles/.config/opencode" ]
    [ -f /opt/opencode-config/opencode.jsonc ]
    [ -L /opt/agents-skills ]
    [ "$(readlink /opt/agents-skills)" = "/opt/dotfiles/agents/skills" ]
    [ -d /opt/agents-skills ]
    [ -L /etc/codex/skills ]
    [ "$(readlink /etc/codex/skills)" = "/opt/dotfiles/agents/skills" ]
    [ -d /etc/codex/skills ]
    [ "$(stat -c '%G' /etc/codex)" = "psacln" ]
    [ "$(stat -c '%a' /etc/codex)" = "2755" ]
    if [ -f /etc/codex/config.toml ]; then
        [ "$(stat -c '%G' /etc/codex/config.toml)" = "psacln" ]
        [ "$(stat -c '%a' /etc/codex/config.toml)" = "640" ]
    fi
}

@test "plesk: Codex runtime is shared without shared writable state" {
    [ -x /opt/codex/bin/codex ]
    [ -x /opt/codex/bin/codex-real ]
    [ -L /usr/local/bin/codex ]
    [ "$(readlink /usr/local/bin/codex)" = "/opt/codex/bin/codex" ]
    [ -x /usr/local/sbin/codex-self-update ]
    [ "$(stat -c '%U:%G' /opt/codex/bin/codex)" = "root:root" ]
    [ "$(stat -c '%a' /opt/codex/bin/codex)" = "755" ]
    [ -f /etc/profile.d/codex-global.sh ]
    ! grep -q CODEX_SQLITE_HOME /etc/profile.d/codex-global.sh
    ! grep -q /opt/codex/state /etc/codex/config.toml
    run visudo -cf /etc/sudoers.d/codex-self-update
    [ "$status" -eq 0 ]
}

@test "plesk: playwright CLI and skill targets are provisioned" {
    [ -x /usr/local/bin/playwright-cli ]
    [ -f /opt/agents-skills/playwright-cli/SKILL.md ]
    run /usr/local/bin/playwright-cli --version
    [ "$status" -eq 0 ]
    run /usr/local/bin/playwright --version
    [ "$status" -eq 127 ]
    [[ "$output" == *"legacy wrapper disabled"* ]]
}

@test "plesk: optional shared caches use psacln" {
    if [ -d /opt/opencode-cache ]; then
        [ "$(stat -c '%G' /opt/opencode-cache)" = "psacln" ]
    fi
    if [ -d /opt/opencode-bin ]; then
        [ "$(stat -c '%G' /opt/opencode-bin)" = "psacln" ]
    fi
    if [ -d /opt/vscode-server ]; then
        [ -d /opt/vscode-server/cli ]
        [ -d /opt/vscode-server/extensions ]
        [ "$(stat -c '%G' /opt/vscode-server)" = "psacln" ]
        [ "$(stat -c '%a' /opt/vscode-server)" = "2775" ]
        [ -L /root/.vscode-server ]
    fi
}

@test "plesk: sync and all modes are idempotent" {
    local marker="PLESK_TEST_MARKER_$(date +%s)"
    printf 'export %s=1\n' "$marker" >>/root/dotfiles/globals.sh
    run bash /root/dotfiles/scripts/plesk-init.sh sync
    [ "$status" -eq 0 ]
    grep -q "$marker" /opt/dotfiles/globals.sh
    sed -i "/$marker/d" /root/dotfiles/globals.sh
    run bash /root/dotfiles/scripts/plesk-init.sh all
    [ "$status" -eq 0 ]
    [ -d /opt/dotfiles ]
    [ -x /opt/nvim/bin/nvim ]
    [ -x /usr/local/bin/bun-bin ]
}
