# AGENTS Guide

Dotfiles for shells, editors, Xmonad, terminals, AI CLIs, and bootstrap automation. The repo is the source of truth; encode durable knowledge as docs, tests, scripts, generated files, or execution plans.

## Invariants

- **NO COMMENTS in any file.** Allowed: shebangs, `# shellcheck ...`, functional pragmas. Markdown prose is documentation.
- No commits unless asked. Never bypass hooks or report skipped/failed checks as passing.
- No secrets. Keep local AI settings and aider files out of git.
- Preserve config style; do not reformat untouched TOML, INI, Rasi, Lua, JSON, YAML, fish, shell, or generated files.
- `init.sh`, `globals.sh`, and `inst-*.sh` support `ubuntu | debian | linuxmint | arch | centos`; macOS only for developer tools.
- `init.sh` is self-contained before `globals.sh`; installers check binary/version and reinstall only with `FORCE=true`.
- Do not modernize legacy shell style unless required; no blanket `set -euo pipefail`.
- `~/.claude/skills` and `~/.codex/skills` remain symlinks to `~/.agents/skills`; see [docs/ai-sync.md](docs/ai-sync.md).
- Do not run WSL scripts on native Linux without approval.
- Announce Docker/UI tests before running; they mutate containers, windows, and sometimes sudo state.

## Agent loop

Inspect -> plan -> implement -> run targeted checks -> inspect runtime/UI evidence when relevant -> self-review -> report validation, skipped layers, state effects, and follow-up debt.

Use in-chat plans for small work. For complex or risky work, create `docs/exec-plans/active/<name>.md` with goal, scope, acceptance criteria, progress, decisions, validation, and debt; move it to `completed/` when done and copy durable debt to the tracker.

Use isolated git worktrees for parallel or long-running work. Keep env vars, ports, caches, logs, metrics, traces, and test state per worktree.

Prefer small PRs with summary, acceptance criteria addressed, validation evidence, UI/runtime artifacts when relevant, and known follow-ups.

## Commands

| Task | Command |
|---|---|
| Install/update | `./init.sh` or `make install` |
| Validate | `make test` |
| Filter tests | `./tests/run-tests.sh -f "pattern"` |
| Lint | `make lint` or `make test-lint` |
| Docker bootstrap | `make test-bootstrap && make test-init` |
| UI window checks | `make test-ui-snap-window` |
| Sync AI tooling | `./scripts/sync-ai.sh` |
| Recompile Xmonad | `M-F6` or `xmonad --recompile && xmonad --restart` |

## Source map

| Need | Source |
|---|---|
| Docs map and doc rules | [docs/index.md](docs/index.md) |
| Bootstrap, flags, installers | [docs/bootstrap.md](docs/bootstrap.md) |
| Tests, lint, Docker/UI checks, validation routing | [docs/testing.md](docs/testing.md) |
| Shell load order and helpers | [docs/shell-env.md](docs/shell-env.md) |
| Script taxonomy and installer contract | [docs/scripts.md](docs/scripts.md) |
| AI config and skill sync | [docs/ai-sync.md](docs/ai-sync.md) |
| Generated F1 help | [docs/help.md](docs/help.md) |

## Style

- Shell: `#!/bin/bash` or `#!/usr/bin/env bash`, 4-space indent, `name() {` functions.
- Makefiles use tabs.
- Use `snake_case` locals/functions and `UPPER_CASE` exports.
- Prefer `cmd_exist`, `print_color`, `installPackages`, `pkg_install`, cached `OS`/`ARCH`, and explicit tests over reminders.
