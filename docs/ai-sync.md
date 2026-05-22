## AI Sync (`scripts/sync-ai.sh`)

Keeps the global AI tool setup aligned across Linux, WSL, and Windows.

### Commands

```bash
./scripts/sync-ai.sh          # Sync everything (default)
./scripts/sync-ai.sh sync     # Sync everything
./scripts/sync-ai.sh config   # Linux config links only
./scripts/sync-ai.sh agents   # Linux ~/.agents and CLI skill links only
./scripts/sync-ai.sh windows  # Windows .agents and config copies from WSL only
```

### Layout

Generic skills live globally under `~/.agents/skills`.

| CLI | Path | How it reads |
|---|---|---|
| Claude Code | `~/.claude/skills` | symlink → `~/.agents/skills` |
| Codex | `~/.codex/skills` | symlink → `~/.agents/skills` |
| OpenCode | `~/.agents/skills` | reads natively |
| Windows tools | `%USERPROFILE%/.agents/skills` | copied from WSL |

Project-specific guidance stays in the project, for example `AGENTS.md`, project config files, or project-local agent definitions. Do not put project-only skills in the global `.agents/skills` tree.

### Config sync

Linux config files are symlinked to the dotfiles copy. Existing regular files are backed up before the symlink is created.

Windows config files are copied from WSL because Windows tools should read real Windows files. This includes the OpenCode `gw` command from `.config/opencode/opencode.jsonc` and Pi's `/gw` prompt template. Pi npm package manifests are synced, then `npm install` is run where an existing Pi npm install is present.

| Source | Linux target | Windows target |
|---|---|---|
| `.claude/settings.json` | `~/.claude/settings.json` | `%USERPROFILE%/.claude/settings.json` |
| `.config/opencode/opencode.jsonc` | `~/.config/opencode/opencode.jsonc` | `%USERPROFILE%/.config/opencode/opencode.jsonc` |
| `.pi/agent/settings.json` | `~/.pi/agent/settings.json` | `%USERPROFILE%/.pi/agent/settings.json` |
| `.pi/agent/npm/package.json` | `~/.pi/agent/npm/package.json` | `%USERPROFILE%/.pi/agent/npm/package.json` |
| `.pi/agent/prompts/` | `~/.pi/agent/prompts/` | `%USERPROFILE%/.pi/agent/prompts/` |

### Environment

| Var | Purpose |
|---|---|
| `DOTFILES_DIR` | Dotfiles checkout, default `$HOME/dotfiles` |
| `DOTFILES_AGENTS_DIR` | Global generic agents source, default `$DOTFILES_DIR/.agents` |
| `AGENTS_DIR` | Linux global agents path, default `$HOME/.agents` |
| `WINDOWS_AGENTS_DIR` | Windows global agents override, default detected Windows profile + `/.agents` |

### Tests

`tests/test-sync-ai.bats` covers Linux links, Windows copies, backup behavior, and WSL detection. Run via `make test-sync-ai`.
