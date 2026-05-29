# AGENTS Guide

Repo-managed dotfiles for shells, editors, Xmonad, terminals, AI CLIs, and bootstrap automation. The repo is the source of truth; encode durable knowledge as docs, tests, scripts, schemas, or plans.

## Non-negotiables

- **NO COMMENTS in any file.** Allowed: shebangs, `# shellcheck ...`, functional pragmas. Markdown prose is documentation; no HTML comments.
- **No commits unless asked.** Never bypass hooks or commit with failed, skipped, or partial validation.
- **No secrets.** Keep local AI settings and aider files out of git.
- **Preserve config style.** Do not reformat TOML, INI, Rasi, Lua, JSON, YAML, fish, or generated docs.
- **Portable shell.** `init.sh`, `globals.sh`, and `inst-*.sh` must support `ubuntu | debian | linuxmint | arch | centos`; macOS for developer tools. After `globals.sh`, use `installPackages` or `pkg_install`.
- **Bootstrap rules.** `init.sh` is self-contained; installers check binary/version and reinstall only when `FORCE=true`.
- **Legacy shell style stays.** Do not add `set -euo pipefail` to legacy scripts just because you touched them.
- **AI skill links stay symlinks.** `~/.claude/skills` and `~/.codex/skills` point to `~/.agents/skills`; see [docs/ai-sync.md](docs/ai-sync.md).
- **WSL scripts need Windows interop.** Do not run `wsl-*.sh` on native Linux without approval.
- **Docker/UI tests mutate state.** Announce before running; UI tests move windows and may need sudo.

## Agent loop

Inspect -> plan -> implement -> run targeted checks -> inspect runtime/UI evidence when relevant -> self-review -> report validation, skipped layers, state effects, and follow-up debt.

Keep PRs small; include summary, acceptance criteria addressed, validation evidence, and known debt.

Use in-chat plans for small work. For complex/risky work, add a plan under `docs/exec-plans/active/` with goal, scope, acceptance criteria, progress, decisions, validation, and debt; move it to `completed/` when done.

Use isolated git worktrees for parallel or long-running work. Keep ports, env, caches, logs, and test state per worktree.

## Commands

| Task | Command |
|---|---|
| Install/update | `./init.sh` or `make install` |
| Local validation | `make test` |
| Filter tests | `./tests/run-tests.sh -f "pattern"` |
| Bootstrap Docker tests | `make test-bootstrap` then `make test-init` |
| UI window tests | `make test-ui-snap-window` |
| Lint | `make lint` or `make test-lint` |
| Sync AI tooling | `./scripts/sync-ai.sh` |
| Recompile Xmonad | `M-F6` or `xmonad --recompile && xmonad --restart` |

## Source map

| Need | Source |
|---|---|
| Docs map and validation routing | [docs/index.md](docs/index.md) |
| Bootstrap, flags, symlinks, installers | [docs/bootstrap.md](docs/bootstrap.md) |
| Tests, lint, Docker, UI checks | [docs/testing.md](docs/testing.md) |
| Shell load order and helpers | [docs/shell-env.md](docs/shell-env.md) |
| Script taxonomy and installer contract | [docs/scripts.md](docs/scripts.md) |
| AI config and skill sync | [docs/ai-sync.md](docs/ai-sync.md) |
| Generated F1 help | [docs/help.md](docs/help.md) |

## Style

- Shebang: `#!/bin/bash` or `#!/usr/bin/env bash`; never `#!/bin/sh`.
- Shell indent: 4 spaces. Makefiles: tabs.
- Names: `snake_case` for variables/functions, `UPPER_CASE` for exported constants, `name() {` for functions.
- Prefer `cmd_exist`, `print_color`, `installPackages`, `pkg_install`, and cached `OS`/`ARCH` from `globals.sh`.
