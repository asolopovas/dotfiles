## AI Sync (`scripts/sync-ai.sh`)

Keeps Claude Code, OpenCode, and Codex aligned: shared skills, MCP servers, and agent definitions.

### Commands

```bash
./scripts/sync-ai.sh                    # Sync everything (default)
./scripts/sync-ai.sh config             # Config files only
./scripts/sync-ai.sh skills             # Skills only
./scripts/sync-ai.sh mcp                # MCP servers only
./scripts/sync-ai.sh agents [sync]      # Agents
./scripts/sync-ai.sh agents add <url>   # Add agent URL → agents.conf
./scripts/sync-ai.sh agents remove <name>
./scripts/sync-ai.sh agents list
```

### Layout (canonical → symlink)

Skills install **once** to `~/.agents/skills/`, then each CLI reads from there:

| CLI | Path | How it reads |
|---|---|---|
| Claude Code | `~/.claude/skills` | symlink → `~/.agents/skills` |
| Codex | `~/.codex/skills` | symlink → `~/.agents/skills` (only if codex installed) |
| OpenCode | `~/.agents/skills` | reads natively |

This is intentional — never duplicate skill files per CLI. If a skill directory is a real dir instead of a symlink, sync will refuse to overwrite — investigate first.

### Configuration

| Var / file | Purpose |
|---|---|
| `agents.conf` (repo root) | Agent URLs, one per line, `#` for comments |
| `AGENTS_CONFIG` | Override path to `agents.conf` |
| `AGENTS_SKILLS_DIR` | Default `~/.agents/skills` |
| `SKILL_INSTALLER` | Path to skill-installer python script |
| `SYNC_TARGETS` | Comma-separated CLIs (default auto-detect: `codex,claude,opencode`) |
| `OPENCODE_CONFIG` | Path to `opencode.json` |
| `CODEX_CONFIG` | Path to codex `config.toml` |

### Skill sources

Defined inline in `SKILL_SOURCES` array at top of `sync-ai.sh`. URLs use the GitHub `tree/<branch>/path` form — the installer extracts that subdirectory.

### Tests

`tests/test-sync-ai.bats` — covers config parsing, agent add/remove/list, and sync target auto-detection. Run via `make test-sync-ai`.
