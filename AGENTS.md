# AGENTS Guide for dotfiles

Personal dotfiles for Linux desktop/server (Ubuntu/Debian primary, Arch/CentOS supported, macOS partial). Covers shells, editors (Neovim), WMs (Xmonad), terminals, AI CLIs, and infra automation. Follow unless the user gives explicit overrides.

## Hard Constraints

- **NO COMMENTS in any file.** Do not write descriptive, explanatory, or section-divider comments — ever, in any language (sh, fish, lua, ts, etc.). The only allowed `#`/`//` lines are: shebangs (`#!/bin/bash`), `# shellcheck …` directives, and other functional pragmas the interpreter actually reads. If you think the WHY is genuinely non-obvious (a workaround, hidden constraint), ask first; do not add it on your own.
- **No commits unless explicitly instructed.**
- **OS-portable shell only.** Anything in `inst-*.sh`, `globals.sh`, or `init.sh` must work on `ubuntu | debian | linuxmint | arch | centos` (and `macos` for the dev tools). Use `installPackages` / `pkg_install` from `globals.sh`, not raw `apt`.
- **`init.sh` must stay self-contained** — it runs before `globals.sh` exists (curl-install path). Don't add `source globals.sh` at the top; the inline helpers there are intentional duplicates.
- **`inst-*.sh` must be idempotent.** Check for the binary or version before downloading. Reinstall only when `FORCE=true`.
- **Never commit secrets.** `.gitignore` excludes `.claude/settings.local.json`, `.aider*` — keep that surface clean.
- **Pre-handoff checklist:** `make test` (always). Add `make test-init` for bootstrap/installer changes; `make test-ui-snap-window` for window-manager changes. If you skip a layer, say so in the handoff.
- **Don't reformat config files.** TOML, INI, Rasi, Lua, JSON, YAML, fish — follow the file's existing convention. No editor reflow.
- **Don't add `set -euo pipefail` to legacy scripts.** Match the existing style of the file you're editing. New scripts should use it.
- **Tests can mutate system state** (windows, mounts, sudo). Note any such effect in the handoff. Never run UI/Docker tests in the background without telling the user — they take focus or several minutes.
- **Symlink discipline for AI skills.** `~/.claude/skills` and `~/.codex/skills` must remain symlinks to `~/.agents/skills`. If you find a real dir there, investigate before overwriting — see [docs/ai-sync.md](docs/ai-sync.md).
- **WSL-specific scripts (`wsl-*.sh`)** assume Windows interop (`powershell.exe`, `adb.exe` on PATH). Don't run them on native Linux without the user's say-so.

## Stack

Bash 5 + Fish 3 (primary shells), Bats (tests), Docker (integration tests), Xmonad (WM), Neovim + Lua, Polybar, Alacritty, Picom, Rofi, fzf. AI: Claude Code, OpenCode, Codex synced via `scripts/sync-ai.sh`.

## Commands

Prefer `make` targets (`make help` for the full list). Drop to raw commands for narrower scope.

| Task | Command |
|---|---|
| Install everything | `./init.sh` (see [docs/bootstrap.md](docs/bootstrap.md) for flags) |
| Local fast tests (~2-5s) | `make test` |
| Single suite | `make test-globals` · `test-scripts` · `test-sync-ai` · `test-inst-opencode` |
| Filter by name | `./tests/run-tests.sh -f "pattern"` |
| Docker init tests | `make test-bootstrap` (once, ~5min) → `make test-init` |
| Docker debug shell | `make test-init-shell` |
| UI tests (X11) | `make test-ui-snap-window` |
| Sync AI tooling | `./scripts/sync-ai.sh` |
| Recompile xmonad | `M-F6` (or `xmonad --recompile && xmonad --restart`) |

## Layout

```
init.sh              Bootstrap (self-contained, curl-installable)
globals.sh           Shared shell library — sourced by .bashrc and most scripts
autostart.sh         Desktop autostart (compositor, polybar, flameshot)
.bashrc / .profile   Bash init (load order in docs/shell-env.md)
Makefile             Test orchestration

scripts/             ~84 scripts, prefixed by category (see naming below)
helpers/             Small CLI wrappers: system/, tools/, web/, plus standalone files
env/                 Shell env exports (env-vars, include-paths, theme, xmonad-vars)
completions/         Shell completions (bash/, fish/)
conf.d/              System config snippets (Barrier, Synaptics)
fzf/                 fzf opts, completion, key-bindings, exclusions
.config/             App configs: nvim, fish, tmux, polybar, rofi, alacritty, gtk, …
tests/               Bats suites + Docker runners (Dockerfile.base, .init-test)
prompts/             AI prompt templates
redis/               Redis 6379 config
docs/                Deep dives — read before touching the area
```

### Script naming

`{category}-{name}.sh` in `scripts/`:

| Prefix | Use |
|---|---|
| `inst-` | Installers (single tool/package) |
| `ops-` | Maintenance (backups, cleanup, restarts) |
| `cfg-` | Configuration tweaks |
| `sec-` | Security (askpass, ban-ips, keyring) |
| `sys-` | System fixes (drivers, kernel, tearing) |
| `ui-` | Desktop / WM (snap-window, polybar, dpi) |
| `wsl-` | WSL-specific (browser, fingerprint, hello) |

Standalone executables installed to `~/.local/bin` omit `.sh`.

### Conventions

- Shebang: `#!/bin/bash` (most) or `#!/usr/bin/env bash` (portable). Never `#!/bin/sh`.
- 4-space indent (tabs only in Makefile). No trailing whitespace.
- `snake_case` vars/funcs. `UPPER_CASE` exports/constants.
- Function form: `name() {` (not `function name`). Declare `local` vars.
- Command checks: `cmd_exist` from `globals.sh` (not inline `command -v` unless one-off).
- Logging: `print_color` from `globals.sh`, or local `log()`/`error()` helpers.

### OS detection pattern

Already cached in `OS` and `ARCH` env vars (set by `globals.sh`). Switch on them:

```bash
case "$OS" in
    ubuntu | debian | linuxmint) ... ;;
    centos)                       ... ;;
    arch)                         ... ;;
    macos)                        ... ;;
esac
```

## Deep Dives

Read the relevant doc before touching the area it covers:

- [docs/bootstrap.md](docs/bootstrap.md) — `init.sh` flow, feature flags, idempotency rules for `inst-*.sh`.
- [docs/testing.md](docs/testing.md) — three test layers (local bats, Docker init, X11 UI), runners, when to run which.
- [docs/shell-env.md](docs/shell-env.md) — `.bashrc` load order, `globals.sh` helper cheat sheet, `env/` directory map.
- [docs/ai-sync.md](docs/ai-sync.md) — `sync-ai.sh` deep dive, symlink layout, `agents.conf`.
- [docs/help.md](docs/help.md) — keyboard shortcuts (xmonad, tmux, nvim, git aliases). Reference for the user-facing F1 cheatsheet.

## Commit & PR

- Short, lowercase, imperative subjects. Optional prefix: `refactor:`, `feat:`, `fix:`.
- PR body: brief summary, key files touched, which test layers ran (or "not run"). Note sudo/system-state changes and OS-specific assumptions.
