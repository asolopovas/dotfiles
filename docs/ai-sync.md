# AI sync

`scripts/sync-ai.sh` syncs AI CLI config and generic skills across Linux, WSL, and Windows.

Generic agent content (skills, `.skill-lock.json`, and per-agent dirs `claude/`, `codex/`, `pi/`, `opencode/`) lives in the private `asolopovas/agents` repo, mounted as a git submodule at `agents/` in this repo and in `winconf`. After cloning or pulling, run `git submodule update --init --recursive`. To change skills: edit inside `agents/`, push that repo, then commit the new submodule pointer here.

## Targets

| Command | Scope |
|---|---|
| `./scripts/sync-ai.sh`, `sync` | Everything |
| `config` | Linux config links |
| `agents` | Linux `~/.agents` plus CLI skill links, plus Plesk vhost AI links when detected |
| `skills` | Skills and Pi prompts, plus Plesk vhost AI links when detected |
| `plesk` | Plesk vhost skills and Pi prompts only |
| `windows` | Windows copies from WSL |

## Skills

Generic skills live in `~/.agents/skills`. Skill directories must be immediate children of that directory, such as `~/.agents/skills/playwright-cli/SKILL.md`; `~/.agents/skills/skills/...` is invalid and `sync-ai.sh` rejects it.

| CLI | Path | Behavior |
|---|---|---|
| Claude Code | `~/.claude/skills` | Symlink to `~/.agents/skills` |
| Codex | `~/.codex/skills` | Symlink to `~/.agents/skills` |
| OpenCode | `~/.config/opencode/skills` | Symlink to `~/.agents/skills` |
| Pi | `~/.pi/agent/skills` | Symlink to `~/.agents/skills` |
| Windows tools | `%USERPROFILE%/.agents/skills` | Copied from WSL |
| Plesk vhosts | `~/.agents`, `~/.claude/skills`, `~/.codex/skills`, `~/.pi/agent/skills` | Symlinks to dotfiles-backed shared skills |

`~/.agents` is a symlink to the `agents/` submodule checkout. OpenCode and Pi additionally read `~/.agents/skills` natively, but the explicit per-CLI symlinks keep all four agents consistent. Do not replace the skill symlinks with real directories.

## Config

Linux targets are symlinks; Windows targets are copies. Existing regular Linux config files are backed up before replacement when content differs. Plesk vhost Pi npm `package.json` is copied instead of symlinked so `pi update` can rewrite it as the vhost user.

| Source | Linux target | Windows target |
|---|---|---|
| `.claude/settings.json` | `~/.claude/settings.json` | `%USERPROFILE%/.claude/settings.json` |
| `.config/opencode/opencode.jsonc` | `~/.config/opencode/opencode.jsonc` | `%USERPROFILE%/.config/opencode/opencode.jsonc` |
| `.pi/agent/settings.json` | `~/.pi/agent/settings.json` | `%USERPROFILE%/.pi/agent/settings.json` |
| `.pi/agent/npm/package.json` | `~/.pi/agent/npm/package.json` | `%USERPROFILE%/.pi/agent/npm/package.json` |
| `.pi/agent/prompts/` | `~/.pi/agent/prompts/` | `%USERPROFILE%/.pi/agent/prompts/` |

When Pi npm exists, sync runs `npm install` and `pi update --extensions` if available.

On Plesk hosts, vhost AI skills, Pi prompts, Pi settings, and OpenCode MCP config are symlinked to the dotfiles checkout. Pi npm `package.json` is copied and owned by each vhost user so package updates remain writable.

## Codex on Plesk

`scripts/plesk-init.sh codex` provisions a root-owned runtime at `/opt/codex`, a wrapper at `/usr/local/bin/codex`, managed config and skills under `/etc/codex`, and a fixed privileged self-update helper. `codex update` invokes that helper without granting vhost users write access to the shared executable.

Each vhost owns a private `~/.codex` directory with mode `0700`. The wrapper forces `CODEX_SQLITE_HOME` to that user's `CODEX_HOME` and removes the obsolete `/opt/codex/state` setting from managed and migrated configs; authentication, configuration, sessions, and SQLite databases are never shared through `/opt/codex/state`. The profile exports only the shared executable path. Existing shared state is retained root-only as legacy data.

Run `scripts/plesk-init.sh sync` after changing the wrapper or vhost provisioning. The tracked runtime sources are `scripts/plesk-codex-wrapper.sh` and `scripts/plesk-codex-self-update.sh`.

Project-only rules belong in `AGENTS.md` or project-local config, not generic skills. Validate with `make test-sync-ai` and `make test`.
