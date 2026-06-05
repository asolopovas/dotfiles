#!/usr/bin/env bats

setup_file() {
    if [ ! -d /opt/dotfiles ] || [ ! -L /var/www/vhosts/test1.com/dotfiles ]; then
        echo "plesk-init.sh must run before vhost tests" >&2
        return 1
    fi
}

@test "vhost1: dotfiles and shell config are linked" {
    local h="/var/www/vhosts/test1.com"
    [ -L "$h/dotfiles" ]
    [ "$(readlink "$h/dotfiles")" = "/opt/dotfiles" ]
    [ "$(stat -c '%U' "$h/dotfiles")" = "testuser1" ]
    for path in "$h/.bashrc" "$h/.gitconfig" "$h/.gitignore" "$h/.config/tmux" "$h/.config/.func" "$h/.config/.aliasrc" "$h/.local/bin/helpers"; do
        [ -L "$path" ]
    done
    for path in "$h/.config" "$h/.local/bin" "$h/.local/share" "$h/.local/state/nvim" "$h/.cache/nvim"; do
        [ -d "$path" ]
    done
}

@test "vhost1: fish, omf, and nvim use shared state safely" {
    local h="/var/www/vhosts/test1.com"
    [ -d "$h/.config/fish" ]
    [ ! -L "$h/.config/fish" ]
    for path in "$h/.config/fish/config.fish" "$h/.config/fish/functions" "$h/.config/fish/conf.d" "$h/.config/fish/completions"; do
        [ -L "$path" ]
    done
    [ -f "$h/.config/fish/fish_variables" ]
    [ "$(stat -c '%U' "$h/.config/fish/fish_variables")" = "testuser1" ]
    [ -L "$h/.local/share/omf" ]
    [ "$(readlink "$h/.local/share/omf")" = "/opt/omf" ]
    [ -d "$h/.config/omf" ]
    [ -L "$h/.config/nvim" ]
    [ "$(readlink "$h/.config/nvim")" = "/opt/nvim-config/nvim" ]
    [ ! -d "$h/.local/nvim" ]
    [ ! -d "$h/.local/share/nvim" ]
    run sudo -u testuser1 bash -c 'touch /opt/nvim-data/nvim/test_write 2>&1'
    [ "$status" -ne 0 ]
}

@test "vhost1: ai and developer caches are shared" {
    local h="/var/www/vhosts/test1.com"
    [ -L "$h/.agents" ]
    [ "$(readlink "$h/.agents")" = "$h/dotfiles/.agents" ]
    [ -L "$h/.claude/skills" ]
    [ "$(readlink "$h/.claude/skills")" = "$h/.agents/skills" ]
    [ -L "$h/.codex/skills" ]
    [ "$(readlink "$h/.codex/skills")" = "$h/.agents/skills" ]
    [ -L "$h/.config/opencode" ]
    [ "$(readlink "$h/.config/opencode")" = "$h/dotfiles/.config/opencode" ]
    [ -L "$h/.pi/agent/prompts" ]
    [ -f "$h/.pi/agent/npm/package.json" ]
    [ "$(stat -c '%U' "$h/.pi/agent/npm/package.json")" = "testuser1" ]
    if [ -d /opt/opencode-cache ]; then
        [ -L "$h/.cache/opencode" ]
        [ "$(readlink "$h/.cache/opencode")" = "/opt/opencode-cache" ]
    fi
    if [ -d /opt/opencode-bin ]; then
        [ -L "$h/.local/share/opencode/bin" ]
        [ "$(readlink "$h/.local/share/opencode/bin")" = "/opt/opencode-bin" ]
    fi
    if [ -d /opt/vscode-server ]; then
        [ -L "$h/.vscode-server" ]
        [ "$(readlink "$h/.vscode-server")" = "/opt/vscode-server" ]
    fi
}

@test "vhost2: essential setup mirrors vhost1" {
    local h="/var/www/vhosts/test2.org"
    [ -L "$h/dotfiles" ]
    [ "$(readlink "$h/dotfiles")" = "/opt/dotfiles" ]
    [ "$(stat -c '%U' "$h/dotfiles")" = "testuser2" ]
    [ -L "$h/.bashrc" ]
    [ -d "$h/.config/fish" ]
    [ ! -L "$h/.config/fish" ]
    [ -L "$h/.local/share/omf" ]
    [ -d "$h/.local/state/nvim" ]
    [ -d "$h/.cache/nvim" ]
    [ "$(stat -c '%U' "$h/.local/state")" = "testuser2" ]
}
