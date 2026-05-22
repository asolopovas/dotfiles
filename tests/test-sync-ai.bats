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

    mkdir -p "$DOTFILES_AGENTS_DIR/skills/skills/example" "$DOTFILES_DIR/.claude" "$DOTFILES_DIR/.config/opencode"
    printf '{}\n' > "$DOTFILES_DIR/.claude/settings.json"
    printf '{}\n' > "$DOTFILES_DIR/.config/opencode/opencode.jsonc"
    printf -- '---\nname: example\ndescription: Test\n---\n' > "$DOTFILES_AGENTS_DIR/skills/skills/example/SKILL.md"

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
    [[ "$(readlink "$FAKE_HOME/.claude/settings.json")" == "$DOTFILES_DIR/.claude/settings.json" ]]
    [[ "$(readlink "$FAKE_HOME/.config/opencode/opencode.jsonc")" == "$DOTFILES_DIR/.config/opencode/opencode.jsonc" ]]
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

@test "windows sync copies agents when running under WSL with override" {
    export WSL_DISTRO_NAME="Ubuntu"
    mkdir -p "$(dirname "$WINDOWS_AGENTS_DIR")"
    sync_windows_agents
    [ -f "$WINDOWS_AGENTS_DIR/skills/skills/example/SKILL.md" ]
}

@test "windows sync copies configs with gw command when running under WSL" {
    export WSL_DISTRO_NAME="Ubuntu"
    mkdir -p "$(dirname "$WINDOWS_AGENTS_DIR")"
    printf '{"command":{"gw":{"template":"commit and push"}}}\n' > "$DOTFILES_DIR/.config/opencode/opencode.jsonc"
    sync_windows_configs
    [ -f "$TMPDIR/windows/.config/opencode/opencode.jsonc" ]
    [[ "$(cat "$TMPDIR/windows/.config/opencode/opencode.jsonc")" == *'"gw"'* ]]
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
    [ -f "$TMPDIR/mnt/c/Users/alice/.agents/skills/skills/example/SKILL.md" ]
}

@test "windows sync is skipped outside WSL" {
    unset WSL_DISTRO_NAME
    sync_windows_agents
    [ ! -e "$WINDOWS_AGENTS_DIR" ]
}

@test "full sync creates agents and config links" {
    run sync_ai_run sync
    [[ "$status" -eq 0 ]]
    [ -L "$AGENTS_DIR" ]
    [ -L "$FAKE_HOME/.claude/skills" ]
    [ -L "$FAKE_HOME/.codex/skills" ]
    [ -L "$FAKE_HOME/.claude/settings.json" ]
}

@test "help prints usage" {
    run sync_ai_run --help
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Usage:"* ]]
}
