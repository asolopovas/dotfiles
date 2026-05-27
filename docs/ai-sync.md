# AI sync

`scripts/sync-ai.sh` syncs AI CLI config and generic skills across Linux, WSL, and Windows.

## Commands

| Command | Scope |
|---|---|
| `./scripts/sync-ai.sh` | Everything |
| `./scripts/sync-ai.sh sync` | Everything |
| `./scripts/sync-ai.sh config` | Linux config links |
| `./scripts/sync-ai.sh agents` | Linux `~/.agents` plus CLI skill links |
| `./scripts/sync-ai.sh windows` | Windows copies from WSL |

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

Linux targets are symlinks to this repo. Windows targets are file copies. Existing regular Linux config files are backed up before replacement when content differs.

| Source | Linux target | Windows target |
|---|---|---|
| `.claude/settings.json` | `~/.claude/settings.json` | `%USERPROFILE%/.claude/settings.json` |
| `.config/opencode/opencode.jsonc` | `~/.config/opencode/opencode.jsonc` | `%USERPROFILE%/.config/opencode/opencode.jsonc` |
| `.pi/agent/settings.json` | `~/.pi/agent/settings.json` | `%USERPROFILE%/.pi/agent/settings.json` |
| `.pi/agent/npm/package.json` | `~/.pi/agent/npm/package.json` | `%USERPROFILE%/.pi/agent/npm/package.json` |
| `.pi/agent/prompts/` | `~/.pi/agent/prompts/` | `%USERPROFILE%/.pi/agent/prompts/` |

When Pi npm exists, sync runs `npm install` and `pi update --extensions` if available.

## Sources

| Path | Purpose |
|---|---|
| `.agents/` | Generic user-level agents and skills |
| `AGENTS.md` | Project-local instructions |
| `.pi/agent/` | Pi settings, prompts, npm manifest |
| `.config/agents.conf` | External agent URL list, tracked but not synced |

Project-only rules belong in `AGENTS.md` or project-local config, not generic skills.

## Environment

| Var | Default |
|---|---|
| `DOTFILES_DIR` | `$HOME/dotfiles` |
| `DOTFILES_AGENTS_DIR` | `$DOTFILES_DIR/.agents` |
| `AGENTS_DIR` | `$HOME/.agents` |
| `WINDOWS_AGENTS_DIR` | Detected Windows profile plus `/.agents` |

## Validation

```bash
make test-sync-ai
make test
```
