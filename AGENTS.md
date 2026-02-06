# Repository Guidelines

Personal dotfiles repository for Linux desktop/server environments. Covers
shell config, editors (Neovim), window managers (Xmonad), terminal emulators,
and infrastructure automation scripts.

## Project Structure

```
init.sh              Bootstrap installer (feature flags: NODE=false ./init.sh)
autostart.sh         Desktop autostart (compositor, polybar, flameshot, etc.)
globals.sh           Shared shell library (print_color, cmd_exist, installPackages, OS detection)
.bashrc / .profile   Shell init, sources globals, env-vars, aliases, completions
Makefile             Build/test automation
scripts/             ~90 scripts, prefixed by category (see naming below)
helpers/             Small CLI wrappers: system/, tools/, web/
env/                 Environment exports (env-vars.sh, include-paths.sh, theme.sh)
completions/         Shell completions: bash/, fish/
conf.d/              System config snippets (Barrier, Synaptics)
tests/               Bats test suites and runners
fzf/                 FZF completion, keybindings, exclusions
.config/             App configs: nvim, fish, tmux, polybar, rofi, alacritty, gtk, etc.
redis/               Redis config (6379.conf)
prompts/             AI prompt templates
```

## Build, Test, and Development Commands

```bash
make help                  # List all available targets
make install               # Install git cache
make test                  # Run all tests (currently test-ui-snap-window)
make test-ui-snap-window   # Run snap-window bats tests (auto-installs deps)
make install-test-deps     # Install bats + gum if missing
make clean-tests           # Remove /tmp test artifacts
```

### Running a Single Test

Tests use [Bats](https://github.com/bats-core/bats-core):

```bash
bats tests/test-ui-snap-window.bats              # Run one test file
bats tests/test-ui-snap-window.bats -f "snap left"  # Filter by name
```

Tests require a running X11 session (`xdotool`, `wmctrl`, `xrandr`)
and may modify system state. Some require sudo.

### Bootstrap

```bash
./init.sh                         # Install everything with defaults
NODE=false FISH=false ./init.sh   # Skip specific features
FORCE=true ./init.sh              # Force-reinstall
```

## Coding Style & Conventions

- **Shebang:** `#!/bin/bash` for most scripts; `#!/usr/bin/env bash` for portable ones. No `#!/bin/sh`.
- **Error handling:** New scripts use `set -euo pipefail`. When editing, match existing style.
- **Indentation:** 4 spaces everywhere (tabs only in Makefile). No trailing whitespace.
- **Variables/functions:** `snake_case`. Exports/constants: `UPPER_CASE`.
- **Functions:** Use `name() {` form (not `function name`). Declare `local` variables.
- **Command checks:** `cmd_exist()` from globals.sh, or inline `command -v foo &>/dev/null`.
- **Logging:** Inline `log()`/`error()` helpers, or `print_color` from `globals.sh`.
- **Config files:** Follow native format conventions (TOML, INI, Rasi, Lua, JSON, YAML). Do not reformat.

### Script Naming: `{category}-{name}.sh`

`inst-` installers, `ops-` maintenance, `cfg-` configuration, `sec-` security,
`sys-` system, `ui-` desktop, `wsl-` WSL-specific.
Standalone executables in `~/.local/bin` omit `.sh`.

### OS Detection

```bash
export OS=$(awk -F= '/^ID=/ {gsub(/"/, "", $2); print tolower($2)}' /etc/os-release)
case $OS in
ubuntu | debian | linuxmint) ... ;;
centos)                       ... ;;
arch)                         ... ;;
esac
```

## Testing Guidelines

- Bats tests in `tests/test-{name}.bats` with `setup()`/`teardown()`
- Use `skip` for missing deps, `run` to capture exit status
- Tests modify system state (windows, terminals) -- note in PRs
- Ensure scripts under test are `chmod +x`

## Commit & Pull Request Guidelines

- Short, lowercase, imperative subjects. Optional prefix: `refactor:`, `feat:`, `fix:`
- PRs: brief summary, key files, test commands run (or "not run")
- Note sudo/system changes or OS-specific assumptions

## Security & Configuration

- Install scripts may edit system files and proxy settings -- review before running
- Never commit secrets; `.gitignore` excludes `.claude/settings.local.json`, `.aider*`

## AI Sync

Skills, MCP servers, and agents synced across OpenCode, Claude Code, and Codex
via `scripts/sync-ai.sh`.

```bash
./scripts/sync-ai.sh                              # Sync everything
./scripts/sync-ai.sh skills                       # Sync skills only
./scripts/sync-ai.sh mcp                          # Sync MCP servers only
./scripts/sync-ai.sh agents sync                  # Sync agents
./scripts/sync-ai.sh agents add https://example.com/a.md
./scripts/sync-ai.sh agents remove agent-name
./scripts/sync-ai.sh agents list
```

- Config: `config/agents.conf` (one URL per line, `#` comments)
- Env: `AGENTS_CONFIG`, `SKILLS_TARGETS`, `OPENCODE_CONFIG`, `CODEX_CONFIG`
- Locations: `~/.config/opencode/`, `~/.claude/`, `~/.codex/`
