# AI sync

`scripts/sync-ai.sh` keeps AI CLI configuration and generic skills aligned across Linux, WSL, and Windows. Project-specific guidance stays in the repo that owns it.

## Commands

| Command | Scope |
|---|---|
| `./scripts/sync-ai.sh` | Sync everything |
| `./scripts/sync-ai.sh sync` | Sync everything |
| `./scripts/sync-ai.sh config` | Linux config links only |
| `./scripts/sync-ai.sh agents` | Linux `~/.agents` and CLI skill links only |
| `./scripts/sync-ai.sh windows` | Windows copies from WSL only |

## Skill layout

Generic skills live under `~/.agents/skills`.

| CLI | Path | Behavior |
|---|---|---|
| Claude Code | `~/.claude/skills` | Symlink to `~/.agents/skills` |
| Codex | `~/.codex/skills` | Symlink to `~/.agents/skills` |
| OpenCode | `~/.agents/skills` | Reads directly |
| Windows tools | `%USERPROFILE%/.agents/skills` | Copied from WSL |

Do not replace `~/.claude/skills` or `~/.codex/skills` with real directories. If either is not a symlink, inspect before changing it.

## Config sync

Linux targets are symlinks to this repo. Windows targets are real file copies because Windows-native tools should read Windows paths. Existing regular Linux config files are backed up before replacement when content differs.

| Source | Linux target | Windows target |
|---|---|---|
| `.claude/settings.json` | `~/.claude/settings.json` | `%USERPROFILE%/.claude/settings.json` |
| `.config/opencode/opencode.jsonc` | `~/.config/opencode/opencode.jsonc` | `%USERPROFILE%/.config/opencode/opencode.jsonc` |
| `.pi/agent/settings.json` | `~/.pi/agent/settings.json` | `%USERPROFILE%/.pi/agent/settings.json` |
| `.pi/agent/npm/package.json` | `~/.pi/agent/npm/package.json` | `%USERPROFILE%/.pi/agent/npm/package.json` |
| `.pi/agent/prompts/` | `~/.pi/agent/prompts/` | `%USERPROFILE%/.pi/agent/prompts/` |

When an existing Pi npm install is present, sync runs `npm install` and `pi update --extensions` where the relevant commands exist.

## Agent definition sources

| Path | Purpose |
|---|---|
| `.agents/` | Generic user-level agents and skills synced to `~/.agents` |
| `AGENTS.md` | Project-local instructions for this repo |
| `.pi/agent/` | Pi settings, prompt templates, and npm package manifest |

Project-only rules belong in `AGENTS.md` or project-local config, not the global `.agents/skills` tree. `.config/agents.conf` is tracked for tools that read external agent URL lists, but `scripts/sync-ai.sh` does not copy or link it today.

## Environment

| Var | Purpose |
|---|---|
| `DOTFILES_DIR` | Dotfiles checkout, default `$HOME/dotfiles` |
| `DOTFILES_AGENTS_DIR` | Generic agents source, default `$DOTFILES_DIR/.agents` |
| `AGENTS_DIR` | Linux global agents path, default `$HOME/.agents` |
| `WINDOWS_AGENTS_DIR` | Windows global agents override, default detected Windows profile plus `/.agents` |

## Validation

`tests/test-sync-ai.bats` covers Linux links, Windows copies, backup behavior, and WSL detection.

```bash
make test-sync-ai
make test
```
