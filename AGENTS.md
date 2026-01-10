# Repository Guidelines

## Project Structure & Module Organization
- `config/` contains app configs (fish, tmux, nvim, polybar, gtk, rofi, etc.).
- `scripts/` holds install/maintenance scripts like `inst-nvim.sh` and `ops-update-git.sh`.
- `helpers/` provides small utilities and wrappers used by scripts and shells.
- `env/`, `conf.d/`, and `completions/` define environment exports, system snippets, and shell completions.
- `tests/` contains Bats-based test suites and runners; `redis/` and `pofiles/` hold service configs and link helpers.
- Top-level entry points include `init.sh`, `autostart.sh`, and `globals.sh`.

## Build, Test, and Development Commands
- `make help` lists the available targets.
- `make install` installs Git cache.
- `./init.sh` bootstraps local dotfiles and tools (uses env flags like `NODE=false` to skip parts).
- `make test` runs `make test-ui-snap-window`.

## Coding Style & Naming Conventions
- Shell scripts are POSIX sh or bash; keep shebangs accurate (`#!/bin/sh` vs `#!/bin/bash`).
- Use 4-space indentation and `snake_case` for functions and variables.
- Keep scripts executable when adding new ones; mirror existing log helpers and `set -eu` usage.
- Config files should follow their native formats (e.g., `*.ini`, `*.toml`, `*.rasi`) without reformatting.

## Testing Guidelines
- Bats tests live in `tests/` (e.g., `tests/test-ui-snap-window.bats`).
- Full tests modify system state and require sudo; call out side effects in PRs.

## Commit & Pull Request Guidelines
- Recent history favors short, lowercase subjects; occasionally uses a conventional prefix like `refactor: sync mcp servers`.
- Use concise, imperative subjects that explain the change; avoid vague “save” messages for new work.
- PRs should include a brief summary, key scripts/configs touched, and test commands run (or “not run”).
- Note any sudo/system changes or OS-specific assumptions in the PR description.

## Security & Configuration Tips
- Many install scripts edit system files and proxy settings; review before running and document changes.

## Agent Sync
Custom agents are synced across OpenCode, Claude Code, and Codex using `sync-agents.sh`.

### Configuration
- Agent URLs are defined in `config/agents.conf`
- One URL per line, comments start with `#`

### Usage
```bash
# Sync agents to all CLIs
./scripts/sync-agents.sh

# Or use the helper script
./scripts/add-agent sync

# Add a new agent
./scripts/add-agent add https://github.com/.../agent.md

# List configured agents
./scripts/add-agent list

# Remove an agent
./scripts/add-agent remove agent-name
```

### Agent Locations
- OpenCode: `~/.config/opencode/agent/`
- Claude Code: `~/.claude/agents/`
- Codex: `~/.codex/agents/` (requires profile-based usage)

### Environment Variables
- `AGENTS_CONFIG`: Path to agents.conf (default: `$HOME/dotfiles/config/agents.conf`)
- `AGENTS_CLI`: Target CLIs, comma-separated (default: `claude,codex,opencode`)
