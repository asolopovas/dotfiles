# AI sync

`scripts/sync-ai.sh` syncs AI CLI config and generic skills across Linux, WSL, and Windows.

## Commands

| Command | Scope |
|---|---|
| `./scripts/sync-ai.sh`, `sync` | Everything |
| `config` | Linux config links |
| `agents` | Linux `~/.agents` plus CLI skill links |
| `windows` | Windows copies from WSL |

## Skills

Generic skills live in `~/.agents/skills`.

| CLI | Path | Behavior |
|---|---|---|
| Claude Code | `~/.claude/skills` | Symlink to `~/.agents/skills` |
| Codex | `~/.codex/skills` | Symlink to `~/.agents/skills` |
| OpenCode | `~/.agents/skills` | Reads directly |
| Windows tools | `%USERPROFILE%/.agents/skills` | Copied from WSL |

Do not replace `~/.claude/skills` or `~/.codex/skills` with real directories.

## Config

Linux targets are symlinks; Windows targets are copies. Existing regular Linux config files are backed up before replacement when content differs.

| Source | Linux target | Windows target |
|---|---|---|
| `.claude/settings.json` | `~/.claude/settings.json` | `%USERPROFILE%/.claude/settings.json` |
| `.config/opencode/opencode.jsonc` | `~/.config/opencode/opencode.jsonc` | `%USERPROFILE%/.config/opencode/opencode.jsonc` |
| `.pi/agent/settings.json` | `~/.pi/agent/settings.json` | `%USERPROFILE%/.pi/agent/settings.json` |
| `.pi/agent/npm/package.json` | `~/.pi/agent/npm/package.json` | `%USERPROFILE%/.pi/agent/npm/package.json` |
| `.pi/agent/prompts/` | `~/.pi/agent/prompts/` | `%USERPROFILE%/.pi/agent/prompts/` |

When Pi npm exists, sync runs `npm install` and `pi update --extensions` if available.

## Sources and env

| Path or var | Purpose |
|---|---|
| `.agents/` | Generic user agents and skills |
| `AGENTS.md` | Project-local instructions |
| `.pi/agent/` | Pi settings, prompts, npm manifest |
| `.config/agents.conf` | External agent URL list; tracked, not synced |
| `DOTFILES_DIR`, `DOTFILES_AGENTS_DIR`, `AGENTS_DIR`, `WINDOWS_AGENTS_DIR` | Path overrides |

Project-only rules belong in `AGENTS.md` or project-local config, not generic skills.

## Validation

`make test-sync-ai` and `make test`.
