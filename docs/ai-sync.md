# AI sync

`scripts/sync-ai.sh` syncs AI CLI config and generic skills across Linux, WSL, and Windows.

## Targets

| Command | Scope |
|---|---|
| `./scripts/sync-ai.sh`, `sync` | Everything |
| `config` | Linux config links |
| `agents` | Linux `~/.agents` plus CLI skill links |
| `windows` | Windows copies from WSL |

## Skills

Generic skills live in `~/.agents/skills`. Skill directories must be immediate children of that directory, such as `~/.agents/skills/playwright-cli/SKILL.md`; `~/.agents/skills/skills/...` is invalid and `sync-ai.sh` rejects it.

| CLI | Path | Behavior |
|---|---|---|
| Claude Code | `~/.claude/skills` | Symlink to `~/.agents/skills` |
| Codex | `~/.codex/skills` | Symlink to `~/.agents/skills` |
| OpenCode | `~/.agents/skills` | Reads directly |
| Windows tools | `%USERPROFILE%/.agents/skills` | Copied from WSL |

Do not replace Claude or Codex skill symlinks with real directories.

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

Project-only rules belong in `AGENTS.md` or project-local config, not generic skills. Validate with `make test-sync-ai` and `make test`.
