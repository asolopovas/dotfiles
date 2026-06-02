#!/usr/bin/env bats

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    export FAKE_HOME="$(mktemp -d)"
    export TMPDIR="$(mktemp -d)"
    export HOME="$FAKE_HOME"
    export DOTFILES_DIR="$TMPDIR/dotfiles"
    export DOTFILES_AGENTS_DIR="$DOTFILES_DIR/.agents"
    export AGENTS_DIR="$FAKE_HOME/.agents"
    export WINDOWS_AGENTS_DIR="$TMPDIR/windows/.agents"
    export PLESK_VHOSTS_DIR="$TMPDIR/var/www/vhosts"

    mkdir -p "$DOTFILES_AGENTS_DIR/skills/example" "$DOTFILES_DIR/.claude" "$DOTFILES_DIR/.config/opencode" "$DOTFILES_DIR/.pi/agent/npm" "$DOTFILES_DIR/.pi/agent/prompts"
    printf '{}\n' > "$DOTFILES_DIR/.claude/settings.json"
    printf '{}\n' > "$DOTFILES_DIR/.config/opencode/opencode.jsonc"
    printf '{"packages":["npm:pi-subagents"]}\n' > "$DOTFILES_DIR/.pi/agent/settings.json"
    printf '{"dependencies":{"pi-subagents":"^0.25.0"}}\n' > "$DOTFILES_DIR/.pi/agent/npm/package.json"
    printf -- '---\ndescription: Commit and push\n---\nCommit and push.\n' > "$DOTFILES_DIR/.pi/agent/prompts/gw.md"
    printf -- '---\nname: example\ndescription: Test\n---\n' > "$DOTFILES_AGENTS_DIR/skills/example/SKILL.md"

    source <(sed 's/^main "\$@"$//' "$REPO_DIR/scripts/sync-ai.sh")
}

teardown() {
    rm -rf "$FAKE_HOME" "$TMPDIR"
}

sync_ai_run() {
    bash "$REPO_DIR/scripts/sync-ai.sh" "$@"
}

@test "agents sync links home agents to dotfiles agents" {
    sync_linux_agents
    [ -L "$AGENTS_DIR" ]
    [[ "$(readlink "$AGENTS_DIR")" == "$DOTFILES_AGENTS_DIR" ]]
}

@test "agents sync links claude and codex skills to shared skills" {
    sync_linux_agents
    [ -L "$FAKE_HOME/.claude/skills" ]
    [ -L "$FAKE_HOME/.codex/skills" ]
    [[ "$(readlink "$FAKE_HOME/.claude/skills")" == "$AGENTS_DIR/skills" ]]
    [[ "$(readlink "$FAKE_HOME/.codex/skills")" == "$AGENTS_DIR/skills" ]]
}

@test "config sync links known config files" {
    sync_linux_configs
    [ -L "$FAKE_HOME/.claude/settings.json" ]
    [ -L "$FAKE_HOME/.config/opencode/opencode.jsonc" ]
    [ -L "$FAKE_HOME/.pi/agent/settings.json" ]
    [ -L "$FAKE_HOME/.pi/agent/npm/package.json" ]
    [ -L "$FAKE_HOME/.pi/agent/prompts" ]
    [[ "$(readlink "$FAKE_HOME/.claude/settings.json")" == "$DOTFILES_DIR/.claude/settings.json" ]]
    [[ "$(readlink "$FAKE_HOME/.config/opencode/opencode.jsonc")" == "$DOTFILES_DIR/.config/opencode/opencode.jsonc" ]]
    [[ "$(readlink "$FAKE_HOME/.pi/agent/settings.json")" == "$DOTFILES_DIR/.pi/agent/settings.json" ]]
    [[ "$(readlink "$FAKE_HOME/.pi/agent/npm/package.json")" == "$DOTFILES_DIR/.pi/agent/npm/package.json" ]]
    [[ "$(readlink "$FAKE_HOME/.pi/agent/prompts")" == "$DOTFILES_DIR/.pi/agent/prompts" ]]
}

@test "config sync replaces identical regular files" {
    mkdir -p "$FAKE_HOME/.claude"
    cp "$DOTFILES_DIR/.claude/settings.json" "$FAKE_HOME/.claude/settings.json"
    sync_linux_configs
    [ -L "$FAKE_HOME/.claude/settings.json" ]
    [[ "$(readlink "$FAKE_HOME/.claude/settings.json")" == "$DOTFILES_DIR/.claude/settings.json" ]]
    [ -z "$(find "$FAKE_HOME/.claude" -name 'settings.json.backup.*' -print -quit)" ]
}

@test "config sync backs up differing regular files" {
    mkdir -p "$FAKE_HOME/.claude"
    printf '{"theme":"local"}\n' > "$FAKE_HOME/.claude/settings.json"
    sync_linux_configs
    [ -L "$FAKE_HOME/.claude/settings.json" ]
    [[ "$(readlink "$FAKE_HOME/.claude/settings.json")" == "$DOTFILES_DIR/.claude/settings.json" ]]
    backup="$(find "$FAKE_HOME/.claude" -name 'settings.json.backup.*' -print -quit)"
    [ -n "$backup" ]
    [[ "$(cat "$backup")" == '{"theme":"local"}' ]]
}

@test "replace_with_symlink is idempotent" {
    sync_linux_agents
    run sync_linux_agents
    [[ "$status" -eq 0 ]]
    [[ "$(readlink "$AGENTS_DIR")" == "$DOTFILES_AGENTS_DIR" ]]
}

@test "replace_with_symlink replaces empty directories" {
    mkdir -p "$AGENTS_DIR" "$FAKE_HOME/.claude/skills" "$FAKE_HOME/.codex/skills"
    sync_linux_agents
    [ -L "$AGENTS_DIR" ]
    [ -L "$FAKE_HOME/.claude/skills" ]
    [ -L "$FAKE_HOME/.codex/skills" ]
}

@test "replace_with_symlink refuses non-empty directories" {
    mkdir -p "$AGENTS_DIR"
    touch "$AGENTS_DIR/existing"
    run sync_linux_agents
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"not an empty directory or symlink"* ]]
}

@test "agents sync rejects nested skills layout" {
    mkdir -p "$DOTFILES_AGENTS_DIR/skills/skills/example"
    run sync_linux_agents
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"skills must live directly under"* ]]
}

@test "windows sync copies agents when running under WSL with override" {
    export WSL_DISTRO_NAME="Ubuntu"
    mkdir -p "$(dirname "$WINDOWS_AGENTS_DIR")"
    sync_windows_agents
    [ -f "$WINDOWS_AGENTS_DIR/skills/example/SKILL.md" ]
}

@test "windows sync copies configs with gw command when running under WSL" {
    export WSL_DISTRO_NAME="Ubuntu"
    mkdir -p "$(dirname "$WINDOWS_AGENTS_DIR")"
    printf '{"command":{"gw":{"template":"commit and push"}}}\n' > "$DOTFILES_DIR/.config/opencode/opencode.jsonc"
    sync_windows_configs
    [ -f "$TMPDIR/windows/.config/opencode/opencode.jsonc" ]
    [ -f "$TMPDIR/windows/.pi/agent/settings.json" ]
    [ -f "$TMPDIR/windows/.pi/agent/npm/package.json" ]
    [ -f "$TMPDIR/windows/.pi/agent/prompts/gw.md" ]
    [[ "$(cat "$TMPDIR/windows/.config/opencode/opencode.jsonc")" == *'"gw"'* ]]
    [[ "$(cat "$TMPDIR/windows/.pi/agent/settings.json")" == *'"npm:pi-subagents"'* ]]
    [[ "$(cat "$TMPDIR/windows/.pi/agent/npm/package.json")" == *'"pi-subagents"'* ]]
}

@test "windows config sync backs up differing regular files" {
    export WSL_DISTRO_NAME="Ubuntu"
    mkdir -p "$TMPDIR/windows/.config/opencode"
    printf '{"command":{"gw":{"template":"commit and push"}}}\n' > "$DOTFILES_DIR/.config/opencode/opencode.jsonc"
    printf '{"local":true}\n' > "$TMPDIR/windows/.config/opencode/opencode.jsonc"
    sync_windows_configs
    [[ "$(cat "$TMPDIR/windows/.config/opencode/opencode.jsonc")" == *'"gw"'* ]]
    backup="$(find "$TMPDIR/windows/.config/opencode" -name 'opencode.jsonc.backup.*' -print -quit)"
    [ -n "$backup" ]
    [[ "$(cat "$backup")" == '{"local":true}' ]]
}

@test "windows sync detects user profile when running under WSL" {
    export WSL_DISTRO_NAME="Ubuntu"
    unset WINDOWS_AGENTS_DIR
    mkdir -p "$TMPDIR/mnt/c/Users/alice"

    wslpath() {
        printf '%s\n' "$TMPDIR/mnt/c/Users/alice"
    }

    powershell.exe() {
        printf 'C:\\Users\\alice\r\n'
    }

    sync_windows_agents
    [ -f "$TMPDIR/mnt/c/Users/alice/.agents/skills/example/SKILL.md" ]
}

@test "windows sync is skipped outside WSL" {
    unset WSL_DISTRO_NAME
    sync_windows_agents
    [ ! -e "$WINDOWS_AGENTS_DIR" ]
}

@test "plesk sync links vhost skills prompts and mcp config to dotfiles" {
    local vhost_home="$PLESK_VHOSTS_DIR/example.com"
    local plesk_user
    plesk_user="$(id -un)"
    mkdir -p "$vhost_home"

    plesk() {
        printf 'example.com\t%s\t%s\n' "$(id -un)" "$PLESK_VHOSTS_DIR/example.com"
    }

    sync_plesk_ai
    [ -L "$vhost_home/.agents" ]
    [ -L "$vhost_home/.claude/skills" ]
    [ -L "$vhost_home/.codex/skills" ]
    [ -L "$vhost_home/.config/opencode" ]
    [ -L "$vhost_home/.pi/agent/settings.json" ]
    [ -L "$vhost_home/.pi/agent/npm/package.json" ]
    [ -L "$vhost_home/.pi/agent/prompts" ]
    [[ "$(readlink "$vhost_home/.agents")" == "$DOTFILES_AGENTS_DIR" ]]
    [[ "$(readlink "$vhost_home/.claude/skills")" == "$vhost_home/.agents/skills" ]]
    [[ "$(readlink "$vhost_home/.codex/skills")" == "$vhost_home/.agents/skills" ]]
    [[ "$(readlink "$vhost_home/.config/opencode")" == "$DOTFILES_DIR/.config/opencode" ]]
    [[ "$(readlink "$vhost_home/.pi/agent/settings.json")" == "$DOTFILES_DIR/.pi/agent/settings.json" ]]
    [[ "$(readlink "$vhost_home/.pi/agent/npm/package.json")" == "$DOTFILES_DIR/.pi/agent/npm/package.json" ]]
    [[ "$(readlink "$vhost_home/.pi/agent/prompts")" == "$DOTFILES_DIR/.pi/agent/prompts" ]]
    [[ "$plesk_user" == "$(id -un)" ]]
}

@test "plesk sync keeps existing agents symlink" {
    local vhost_home="$PLESK_VHOSTS_DIR/example.com"
    mkdir -p "$vhost_home"
    ln -s "$DOTFILES_AGENTS_DIR" "$vhost_home/.agents"

    plesk() {
        printf 'example.com\t%s\t%s\n' "$(id -un)" "$PLESK_VHOSTS_DIR/example.com"
    }

    sync_plesk_ai
    [ -L "$vhost_home/.agents" ]
    [[ "$(readlink "$vhost_home/.agents")" == "$DOTFILES_AGENTS_DIR" ]]
    [ -L "$vhost_home/.claude/skills" ]
    [ -L "$vhost_home/.pi/agent/prompts" ]
}

@test "plesk sync backs up duplicate directories before linking shared agent paths" {
    local vhost_home="$PLESK_VHOSTS_DIR/example.com"
    mkdir -p "$vhost_home/.agents/skills/local" "$vhost_home/.config/opencode"
    printf 'local\n' > "$vhost_home/.agents/skills/local/SKILL.md"
    printf 'local\n' > "$vhost_home/.config/opencode/local.json"

    plesk() {
        printf 'example.com\t%s\t%s\n' "$(id -un)" "$PLESK_VHOSTS_DIR/example.com"
    }

    sync_plesk_ai
    [ -L "$vhost_home/.agents" ]
    [ -L "$vhost_home/.config/opencode" ]
    [[ "$(readlink "$vhost_home/.agents")" == "$DOTFILES_AGENTS_DIR" ]]
    [[ "$(readlink "$vhost_home/.config/opencode")" == "$DOTFILES_DIR/.config/opencode" ]]
    agents_backup="$(find "$vhost_home" -maxdepth 1 -name '.agents.backup.*' -print -quit)"
    opencode_backup="$(find "$vhost_home/.config" -maxdepth 1 -name 'opencode.backup.*' -print -quit)"
    [ -n "$agents_backup" ]
    [ -n "$opencode_backup" ]
    [ -f "$agents_backup/skills/local/SKILL.md" ]
    [ -f "$opencode_backup/local.json" ]
}

@test "linux npm package sync updates installed packages" {
    mkdir -p "$FAKE_HOME/bin" "$FAKE_HOME/.pi/agent/npm/node_modules"
    cat > "$FAKE_HOME/bin/npm" <<'S'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$HOME/npm.args"
S
    chmod +x "$FAKE_HOME/bin/npm"
    PATH="$FAKE_HOME/bin:$PATH" sync_linux_npm_packages
    [[ "$(cat "$FAKE_HOME/npm.args")" == "install --prefix $FAKE_HOME/.pi/agent/npm" ]]
}

@test "linux npm package sync rebuilds after npm invalid argument failure" {
    mkdir -p "$FAKE_HOME/bin" "$FAKE_HOME/.pi/agent/npm/node_modules"
    touch "$FAKE_HOME/.pi/agent/npm/package-lock.json"
    printf '0\n' > "$FAKE_HOME/npm.count"
    cat > "$FAKE_HOME/bin/npm" <<'S'
#!/usr/bin/env bash
count="$(cat "$HOME/npm.count")"
if [[ "$count" == "0" ]]; then
    printf 'npm error code ERR_INVALID_ARG_TYPE\n' >&2
    printf 'npm error The "from" argument must be of type string. Received undefined\n' >&2
    printf '1\n' > "$HOME/npm.count"
    exit 1
fi
[[ ! -e "$HOME/.pi/agent/npm/node_modules" ]]
[[ ! -e "$HOME/.pi/agent/npm/package-lock.json" ]]
printf '%s\n' "$*" > "$HOME/npm.args"
S
    chmod +x "$FAKE_HOME/bin/npm"
    PATH="$FAKE_HOME/bin:$PATH" sync_linux_npm_packages
    [[ "$(cat "$FAKE_HOME/npm.count")" == "1" ]]
    [[ "$(cat "$FAKE_HOME/npm.args")" == "install --prefix $FAKE_HOME/.pi/agent/npm" ]]
}

@test "linux pi package sync updates installed packages" {
    mkdir -p "$FAKE_HOME/bin" "$FAKE_HOME/.pi/agent/npm/node_modules"
    cat > "$FAKE_HOME/bin/pi" <<'S'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$HOME/pi.args"
S
    chmod +x "$FAKE_HOME/bin/pi"
    PATH="$FAKE_HOME/bin:$PATH" sync_linux_pi_packages
    [[ "$(cat "$FAKE_HOME/pi.args")" == "update --extensions" ]]
}

@test "full sync creates agents and config links" {
    run sync_ai_run sync
    [[ "$status" -eq 0 ]]
    [ -L "$AGENTS_DIR" ]
    [ -L "$FAKE_HOME/.claude/skills" ]
    [ -L "$FAKE_HOME/.codex/skills" ]
    [ -L "$FAKE_HOME/.claude/settings.json" ]
    [ -L "$FAKE_HOME/.pi/agent/settings.json" ]
    [ -L "$FAKE_HOME/.pi/agent/prompts" ]
}

@test "help prints usage" {
    run sync_ai_run --help
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Usage:"* ]]
}
