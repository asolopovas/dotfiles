#!/usr/bin/env bats

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    export FAKE_HOME="$(mktemp -d)"
    export TMPDIR="$(mktemp -d)"
    export HOME="$FAKE_HOME"
    export DOTFILES_DIR="$TMPDIR/dotfiles"
    export DOTFILES_AGENTS_DIR="$DOTFILES_DIR/agents"
    export AGENTS_DIR="$FAKE_HOME/.agents"
    export WINDOWS_AGENTS_DIR="$TMPDIR/windows/.agents"
    export PLESK_VHOSTS_DIR="$TMPDIR/var/www/vhosts"

    mkdir -p "$DOTFILES_AGENTS_DIR/skills/example" "$DOTFILES_DIR/.claude" "$DOTFILES_DIR/.config/opencode" "$DOTFILES_DIR/.pi/agent/npm" "$DOTFILES_DIR/.pi/agent/prompts"
    printf '{}\n' >"$DOTFILES_DIR/.claude/settings.json"
    printf '{}\n' >"$DOTFILES_DIR/.config/opencode/opencode.jsonc"
    printf '{"packages":["npm:pi-subagents"]}\n' >"$DOTFILES_DIR/.pi/agent/settings.json"
    printf '{"dependencies":{"pi-subagents":"^0.25.0"}}\n' >"$DOTFILES_DIR/.pi/agent/npm/package.json"
    printf -- '---\ndescription: Commit and push\n---\nCommit and push.\n' >"$DOTFILES_DIR/.pi/agent/prompts/gw.md"
    printf -- '---\nname: example\ndescription: Test\n---\n' >"$DOTFILES_AGENTS_DIR/skills/example/SKILL.md"

    source <(sed 's/^main "\$@"$//' "$REPO_DIR/scripts/sync-ai.sh")
}

teardown() {
    rm -rf "$FAKE_HOME" "$TMPDIR"
}

sync_ai_run() {
    bash "$REPO_DIR/scripts/sync-ai.sh" "$@"
}

@test "sync-ai: linux agents and configs are linked" {
    sync_linux_agents
    sync_linux_configs
    [ -L "$AGENTS_DIR" ]
    [ "$(readlink "$AGENTS_DIR")" = "$DOTFILES_AGENTS_DIR" ]
    [ -L "$FAKE_HOME/.claude/skills" ]
    [ -L "$FAKE_HOME/.codex/skills" ]
    [ -L "$FAKE_HOME/.config/opencode/skills" ]
    [ -L "$FAKE_HOME/.pi/agent/skills" ]
    [ "$(readlink "$FAKE_HOME/.claude/skills")" = "$AGENTS_DIR/skills" ]
    [ "$(readlink "$FAKE_HOME/.pi/agent/skills")" = "$AGENTS_DIR/skills" ]
    for path in "$FAKE_HOME/.claude/settings.json" "$FAKE_HOME/.config/opencode/opencode.jsonc" "$FAKE_HOME/.pi/agent/settings.json" "$FAKE_HOME/.pi/agent/npm/package.json" "$FAKE_HOME/.pi/agent/prompts"; do
        [ -L "$path" ]
    done
}

@test "sync-ai: existing files are preserved only when different" {
    mkdir -p "$FAKE_HOME/.claude"
    cp "$DOTFILES_DIR/.claude/settings.json" "$FAKE_HOME/.claude/settings.json"
    sync_linux_configs
    [ -L "$FAKE_HOME/.claude/settings.json" ]
    [ -z "$(find "$FAKE_HOME/.claude" -name 'settings.json.backup.*' -print -quit)" ]
    rm "$FAKE_HOME/.claude/settings.json"
    printf '{"theme":"local"}\n' >"$FAKE_HOME/.claude/settings.json"
    sync_linux_configs
    local backup
    backup="$(find "$FAKE_HOME/.claude" -name 'settings.json.backup.*' -print -quit)"
    [ -n "$backup" ]
    [ "$(cat "$backup")" = '{"theme":"local"}' ]
}

@test "sync-ai: symlink replacement is safe" {
    mkdir -p "$AGENTS_DIR" "$FAKE_HOME/.claude/skills" "$FAKE_HOME/.codex/skills"
    sync_linux_agents
    run sync_linux_agents
    [ "$status" -eq 0 ]
    [ -L "$AGENTS_DIR" ]
    rm "$AGENTS_DIR"
    mkdir -p "$AGENTS_DIR"
    touch "$AGENTS_DIR/existing"
    run sync_linux_agents
    [ "$status" -ne 0 ]
    [[ "$output" == *"not an empty directory or symlink"* ]]
}

@test "sync-ai: rejects nested skills layout" {
    mkdir -p "$DOTFILES_AGENTS_DIR/skills/skills/example"
    run sync_linux_agents
    [ "$status" -ne 0 ]
    [[ "$output" == *"skills must live directly under"* ]]
}

@test "sync-ai: windows sync copies agents and configs under WSL" {
    export WSL_DISTRO_NAME="Ubuntu"
    mkdir -p "$(dirname "$WINDOWS_AGENTS_DIR")"
    printf '{"command":{"gw":{"template":"commit and push"}}}\n' >"$DOTFILES_DIR/.config/opencode/opencode.jsonc"
    sync_windows_agents
    sync_windows_configs
    [ -f "$WINDOWS_AGENTS_DIR/skills/example/SKILL.md" ]
    [ -f "$TMPDIR/windows/.config/opencode/opencode.jsonc" ]
    [ -f "$TMPDIR/windows/.pi/agent/settings.json" ]
    [ -f "$TMPDIR/windows/.pi/agent/npm/package.json" ]
    [ -f "$TMPDIR/windows/.pi/agent/prompts/gw.md" ]
    [[ "$(cat "$TMPDIR/windows/.config/opencode/opencode.jsonc")" == *'"gw"'* ]]
}

@test "sync-ai: windows sync backs up differing files and skips outside WSL" {
    export WSL_DISTRO_NAME="Ubuntu"
    mkdir -p "$TMPDIR/windows/.config/opencode"
    printf '{"command":{"gw":{"template":"commit and push"}}}\n' >"$DOTFILES_DIR/.config/opencode/opencode.jsonc"
    printf '{"local":true}\n' >"$TMPDIR/windows/.config/opencode/opencode.jsonc"
    sync_windows_configs
    local backup
    backup="$(find "$TMPDIR/windows/.config/opencode" -name 'opencode.jsonc.backup.*' -print -quit)"
    [ -n "$backup" ]
    [ "$(cat "$backup")" = '{"local":true}' ]
    unset WSL_DISTRO_NAME
    rm -rf "$TMPDIR/windows"
    sync_windows_agents
    [ ! -e "$WINDOWS_AGENTS_DIR" ]
}

@test "sync-ai: detects Windows profile path under WSL" {
    export WSL_DISTRO_NAME="Ubuntu"
    unset WINDOWS_AGENTS_DIR
    mkdir -p "$TMPDIR/mnt/c/Users/alice"
    wslpath() { printf '%s\n' "$TMPDIR/mnt/c/Users/alice"; }
    powershell.exe() { printf 'C:\\Users\\alice\r\n'; }
    sync_windows_agents
    [ -f "$TMPDIR/mnt/c/Users/alice/.agents/skills/example/SKILL.md" ]
}

@test "sync-ai: plesk sync links shared config with writable package config" {
    local vhost_home="$PLESK_VHOSTS_DIR/example.com"
    mkdir -p "$vhost_home"
    plesk() { printf 'example.com\t%s\t%s\n' "$(id -un)" "$vhost_home"; }
    sync_plesk_ai
    [ -L "$vhost_home/.agents" ]
    [ -L "$vhost_home/.claude/skills" ]
    [ -L "$vhost_home/.codex/skills" ]
    [ -L "$vhost_home/.config/opencode" ]
    [ -L "$vhost_home/.pi/agent/settings.json" ]
    [ -f "$vhost_home/.pi/agent/npm/package.json" ]
    [ ! -L "$vhost_home/.pi/agent/npm/package.json" ]
    [ -L "$vhost_home/.pi/agent/prompts" ]
    cmp -s "$DOTFILES_DIR/.pi/agent/npm/package.json" "$vhost_home/.pi/agent/npm/package.json"
}

@test "sync-ai: plesk sync backs up duplicate directories" {
    local vhost_home="$PLESK_VHOSTS_DIR/example.com"
    mkdir -p "$vhost_home/.agents/skills/local" "$vhost_home/.config/opencode"
    printf 'local\n' >"$vhost_home/.agents/skills/local/SKILL.md"
    printf 'local\n' >"$vhost_home/.config/opencode/local.json"
    plesk() { printf 'example.com\t%s\t%s\n' "$(id -un)" "$vhost_home"; }
    sync_plesk_ai
    [ -L "$vhost_home/.agents" ]
    [ -L "$vhost_home/.config/opencode" ]
    [ -f "$(find "$vhost_home" -maxdepth 1 -name '.agents.backup.*' -print -quit)/skills/local/SKILL.md" ]
    [ -f "$(find "$vhost_home/.config" -maxdepth 1 -name 'opencode.backup.*' -print -quit)/local.json" ]
}

@test "sync-ai: linux package sync invokes package managers" {
    mkdir -p "$FAKE_HOME/bin" "$FAKE_HOME/.pi/agent/npm/node_modules"
    cat >"$FAKE_HOME/bin/npm" <<'S'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$HOME/npm.args"
S
    cat >"$FAKE_HOME/bin/pi" <<'S'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$HOME/pi.args"
S
    chmod +x "$FAKE_HOME/bin/npm" "$FAKE_HOME/bin/pi"
    PATH="$FAKE_HOME/bin:$PATH" sync_linux_npm_packages
    PATH="$FAKE_HOME/bin:$PATH" sync_linux_pi_packages
    [ "$(cat "$FAKE_HOME/npm.args")" = "install --prefix $FAKE_HOME/.pi/agent/npm" ]
    [ "$(cat "$FAKE_HOME/pi.args")" = "update --extensions" ]
}

@test "sync-ai: npm invalid argument rebuilds package tree" {
    mkdir -p "$FAKE_HOME/bin" "$FAKE_HOME/.pi/agent/npm/node_modules"
    touch "$FAKE_HOME/.pi/agent/npm/package-lock.json"
    printf '0\n' >"$FAKE_HOME/npm.count"
    cat >"$FAKE_HOME/bin/npm" <<'S'
#!/usr/bin/env bash
count="$(cat "$HOME/npm.count")"
if [[ "$count" == "0" ]]; then
    printf 'npm error code ERR_INVALID_ARG_TYPE\n' >&2
    printf 'npm error The "from" argument must be of type string. Received undefined\n' >&2
    printf '1\n' >"$HOME/npm.count"
    exit 1
fi
[[ ! -e "$HOME/.pi/agent/npm/node_modules" ]]
[[ ! -e "$HOME/.pi/agent/npm/package-lock.json" ]]
printf '%s\n' "$*" >"$HOME/npm.args"
S
    chmod +x "$FAKE_HOME/bin/npm"
    PATH="$FAKE_HOME/bin:$PATH" sync_linux_npm_packages
    [ "$(cat "$FAKE_HOME/npm.count")" = "1" ]
    [ "$(cat "$FAKE_HOME/npm.args")" = "install --prefix $FAKE_HOME/.pi/agent/npm" ]
}

@test "sync-ai: help prints usage" {
    run sync_ai_run --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}
