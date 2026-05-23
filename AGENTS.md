# AGENTS Guide for dotfiles

Personal Linux desktop/server dotfiles for shells, editors, Xmonad, terminals, AI CLIs, and infra automation. Treat this file as the compact map; topic details live in [docs/](docs/index.md).

## Hard Constraints

- **NO COMMENTS in any file.** Do not write descriptive, explanatory, or section-divider comments in any language or config. Allowed exceptions are shebangs, `# shellcheck ...` directives, and functional pragmas the interpreter or tool reads. Markdown prose is documentation; do not add HTML comments. If a non-obvious workaround needs explanation, ask first.
- **No commits unless explicitly instructed.**
- **OS-portable shell only.** Anything in `inst-*.sh`, `globals.sh`, or `init.sh` must work on `ubuntu | debian | linuxmint | arch | centos` and macOS for developer tools. Use `installPackages` or `pkg_install`, not raw `apt`, after `globals.sh` is available.
- **`init.sh` must stay self-contained.** It runs before `globals.sh` exists in the curl-install path.
- **`inst-*.sh` must be idempotent.** Check the binary or version before downloading. Reinstall only when `FORCE=true`.
- **Never commit secrets.** `.gitignore` excludes local AI settings and aider files; keep that surface clean.
- **Use targeted tests while developing.** Run full local validation once: use `make test` when not committing, or let the pre-commit hook run it when committing. Do not run both for the same tree. Add `make test-init` for bootstrap/installer changes and `make test-ui-snap-window` for window-manager changes. State skipped layers.
- **Do not reformat config files.** Preserve TOML, INI, Rasi, Lua, JSON, YAML, and fish conventions.
- **Do not add `set -euo pipefail` to legacy scripts.** Match the file style. New scripts should use it.
- **UI and Docker tests can mutate state.** UI tests move windows and may need sudo; Docker tests can take minutes. Do not run them in the background without telling the user.
- **AI skill links are intentional.** `~/.claude/skills` and `~/.codex/skills` must stay symlinks to `~/.agents/skills`; see [docs/ai-sync.md](docs/ai-sync.md).
- **WSL scripts require Windows interop.** Do not run `wsl-*.sh` on native Linux without user approval.

## Stack

Bash 5, Fish 3, Bats, Docker, Xmonad, Neovim/Lua, Polybar, Alacritty, Picom, Rofi, fzf, Claude Code, OpenCode, Codex, and Pi.

## Commands

Prefer `make` targets; use `make help` for the full list.

| Task | Command |
|---|---|
| Install everything | `./init.sh` or `make install` |
| Local fast tests | `make test` |
| Single suite | `make test-globals` · `make test-scripts` · `make test-sync-ai` · `make test-inst-opencode` · `make test-inst-picom` |
| Filter by test name | `./tests/run-tests.sh -f "pattern"` |
| Docker init tests | `make test-bootstrap` then `make test-init` |
| Docker debug shell | `make test-init-shell` |
| UI tests | `make test-ui-snap-window` |
| Lint | `make lint` or `make test-lint` |
| Enable git hooks | `make install-git-hooks` |
| Sync AI tooling | `./scripts/sync-ai.sh` |
| Recompile Xmonad | `M-F6` or `xmonad --recompile && xmonad --restart` |

## Layout

```text
init.sh              Curl-safe bootstrap
globals.sh           Shared shell library
autostart.sh         Desktop autostart
.bashrc / .profile   Bash load path
Makefile             Test, lint, install, utility targets
scripts/             Install, config, ops, system, UI, WSL scripts
helpers/             CLI wrappers installed on PATH
env/                 Shared shell environment fragments
completions/         Bash and fish completions
conf.d/              System config snippets
fzf/                 fzf options, keybindings, exclusions
.config/             Application configs
tests/               Bats suites plus Docker/X11 runners
docs/                Source-of-record documentation
```

## Conventions

- Shebang: `#!/bin/bash` or `#!/usr/bin/env bash`. Never `#!/bin/sh`.
- Indent shell with 4 spaces. Tabs only in Makefiles.
- Use `snake_case` for variables/functions and `UPPER_CASE` for exported constants.
- Function form: `name() {`, not `function name`.
- Prefer `cmd_exist` from `globals.sh` over ad hoc command checks.
- Prefer `print_color` from `globals.sh`, or local `log()`/`error()` helpers.
- Script taxonomy and installer rules live in [docs/scripts.md](docs/scripts.md).

## OS pattern

`globals.sh` exports cached `OS` and `ARCH`. Switch on them instead of probing repeatedly.

```bash
case "$OS" in
    ubuntu | debian | linuxmint) ... ;;
    centos)                       ... ;;
    arch)                         ... ;;
    macos)                        ... ;;
esac
```

## Deep docs

Read the relevant source of record before changing an area:

- [docs/index.md](docs/index.md) — documentation map and validation routing.
- [docs/bootstrap.md](docs/bootstrap.md) — `init.sh`, feature flags, symlinks, Plesk path, installer idempotency.
- [docs/testing.md](docs/testing.md) — local, Docker, UI, and lint checks.
- [docs/shell-env.md](docs/shell-env.md) — Bash load order, `globals.sh`, `env/`.
- [docs/scripts.md](docs/scripts.md) — script categories, naming, installer contract.
- [docs/ai-sync.md](docs/ai-sync.md) — AI skill/config sync and symlink discipline.
- [docs/help.md](docs/help.md) — generated F1 keyboard cheatsheet.

## Commit and PR

- Use short, lowercase, imperative subjects. Optional prefix: `refactor:`, `feat:`, `fix:`.
- PR bodies should list summary, key files, tests run or skipped, system-state effects, and OS assumptions.
