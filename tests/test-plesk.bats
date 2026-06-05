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
    [ ! -d /opt/dotfiles/.git ]
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

@test "plesk: bun and pi wrappers are installed" {
    [ -x /usr/local/bin/bun-bin ]
    [ -x /usr/local/bin/bun ]
    [ -x /usr/local/bin/bun-run ]
    [ -L /usr/local/bin/bunx ]
    [ -d /var/www/bun-cache ]
    [ -f /etc/profile.d/bun.sh ]
    run visudo -cf /etc/sudoers.d/bun-cache
    [ "$status" -eq 0 ]
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
    [ "$(readlink /opt/agents-skills)" = "/opt/dotfiles/.agents/skills" ]
    [ -L /etc/codex/skills ]
    [ "$(readlink /etc/codex/skills)" = "/opt/dotfiles/.agents/skills" ]
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
